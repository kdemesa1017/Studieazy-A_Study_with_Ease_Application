import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/app_config.dart';
import '../models/quiz_model.dart';
import '../models/question_model.dart';

/// Result returned by [GeminiService.generateQuiz].
class GeneratedQuizResult {
  final String title;
  final String? description;
  final String? category;
  final List<GeneratedQuestion> questions;

  GeneratedQuizResult({
    required this.title,
    this.description,
    this.category,
    required this.questions,
  });
}

class GeneratedQuestion {
  final String questionText;
  final List<String> options;
  final int correctAnswerIndex;
  final bool isFlashcard;
  final String? flashcardBack;
  final String questionType; // 'mcq', 'flashcard', 'identification', 'enumeration'

  GeneratedQuestion({
    required this.questionText,
    required this.options,
    required this.correctAnswerIndex,
    required this.isFlashcard,
    this.flashcardBack,
    this.questionType = 'mcq',
  });
}

class GeminiService {
  static String? _cachedApiKey;

  /// Resolves the active Gemini API key dynamically from Firestore (priority 1) or AppConfig (priority 2).
  static Future<String> getEffectiveApiKey() async {
    if (_cachedApiKey != null && _cachedApiKey!.isNotEmpty) {
      return _cachedApiKey!;
    }

    // 1. Fetch dynamically from Firestore system_config/ai (allows remote updates without rebuild)
    try {
      final doc = await FirebaseFirestore.instance
          .collection('system_config')
          .doc('ai')
          .get();
      if (doc.exists && doc.data() != null) {
        final remoteKey = (doc.data()!['gemini_api_key'] ??
                doc.data()!['apiKey'] ??
                doc.data()!['geminiApiKey']) as String?;
        if (remoteKey != null && remoteKey.trim().isNotEmpty) {
          _cachedApiKey = remoteKey.trim();
          return _cachedApiKey!;
        }
      }
    } catch (_) {}

    // 2. Fallback to AppConfig.geminiApiKey
    final configKey = AppConfig.geminiApiKey.trim();
    if (configKey.isNotEmpty &&
        configKey != 'YOUR_GEMINI_API_KEY' &&
        configKey != 'GEMINI_API_KEY') {
      _cachedApiKey = configKey;
      return configKey;
    }

    throw Exception(
      'Missing Gemini API Key!\n\n'
      'Please add your Gemini API Key in Firestore "system_config/ai" or in lib/config/app_config.dart.',
    );
  }

  /// Generate a quiz from multiple files simultaneously.
  Future<GeneratedQuizResult> generateQuizFromMultipleFiles({
    required List<({Uint8List bytes, String fileName})> files,
    int questionCount = 10,
    String difficulty = 'Medium',
    List<String>? selectedTypes,
    String? customInstruction,
  }) async {
    if (files.isEmpty) {
      throw Exception('No files selected.');
    }
    if (files.length == 1) {
      return generateQuiz(
        fileBytes: files.first.bytes,
        fileName: files.first.fileName,
        questionCount: questionCount,
        difficulty: difficulty,
        selectedTypes: selectedTypes,
        customInstruction: customInstruction,
      );
    }

    final apiKey = await getEffectiveApiKey();

    final prompt = _buildPrompt(questionCount, difficulty, selectedTypes, customInstruction);
    final List<Part> parts = [];

    for (var i = 0; i < files.length; i++) {
      final f = files[i];
      final ext = f.fileName.split('.').last.toLowerCase();
      if (ext == 'pdf') {
        parts.add(DataPart('application/pdf', f.bytes));
      } else {
        final text = await extractText(f.bytes, ext);
        if (text != null && text.trim().isNotEmpty) {
          parts.add(TextPart('DOCUMENT ${i + 1} (${f.fileName}):\n$text'));
        }
      }
    }
    parts.add(TextPart(prompt));

    final modelsToTry = [
      AppConfig.geminiModel,
      'gemini-2.5-flash',
      'gemini-3.6-flash',
      'gemini-3.7-flash',
      'gemini-flash-latest',
      'gemini-2.5-pro',
      'gemini-pro-latest',
    ];

    Object? lastError;
    GenerateContentResponse? response;

    for (final modelName in modelsToTry) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0.4,
          ),
        );
        final res = await model.generateContent([Content.multi(parts)]);
        if (res.text != null && res.text!.isNotEmpty) {
          response = res;
          break;
        }
      } catch (e) {
        lastError = e;
      }
    }

    if (response == null || response.text == null || response.text!.isEmpty) {
      throw lastError ?? Exception('Gemini returned an empty response. Please try again.');
    }

    return _parseResponse(response.text!);
  }

  // ── Public API ───────────────────────────────────────────────────────────────

  /// Extract readable text from file bytes depending on [extension].
  /// Returns null if extraction fails or format is unsupported.
  Future<String?> extractText(
    Uint8List bytes,
    String extension,
  ) async {
    switch (extension.toLowerCase()) {
      case 'txt':
        return utf8.decode(bytes, allowMalformed: true);
      case 'docx':
        return _extractDocxText(bytes);
      case 'pptx':
        return _extractPptxText(bytes);
      case 'pdf':
        // PDFs are sent as inline bytes directly to Gemini — return null here.
        return null;
      default:
        return utf8.decode(bytes, allowMalformed: true);
    }
  }

  /// Generate a quiz from [fileBytes].
  /// [fileName] is used to determine MIME type.
  /// [questionCount] controls how many questions to ask for (up to 50).
  /// [difficulty] controls question complexity ('Easy', 'Medium', 'High', 'Extreme').
  /// [customInstruction] custom prompt / chatbox instructions from user.
  Future<GeneratedQuizResult> generateQuiz({
    required Uint8List fileBytes,
    required String fileName,
    int questionCount = 10,
    String difficulty = 'Medium',
    List<String>? selectedTypes,
    String? customInstruction,
  }) async {
    final apiKey = await getEffectiveApiKey();

    final ext = fileName.split('.').last.toLowerCase();
    final prompt = _buildPrompt(questionCount, difficulty, selectedTypes, customInstruction);

    List<Part> parts;

    if (ext == 'pdf') {
      // Send PDF bytes directly — Gemini understands PDFs natively.
      parts = [
        DataPart('application/pdf', fileBytes),
        TextPart(prompt),
      ];
    } else {
      // For TXT / DOCX / PPTX extract text first.
      final text = await extractText(fileBytes, ext);
      if (text == null || text.trim().isEmpty) {
        throw Exception(
          'Could not extract text from the file. '
          'Try saving it as a PDF or plain text.',
        );
      }
      parts = [TextPart('$prompt\n\nDOCUMENT CONTENT:\n$text')];
    }

    final modelsToTry = [
      AppConfig.geminiModel,
      'gemini-2.5-flash',
      'gemini-3.6-flash',
      'gemini-3.7-flash',
      'gemini-flash-latest',
      'gemini-2.5-pro',
      'gemini-pro-latest',
    ];

    Object? lastError;
    GenerateContentResponse? response;

    for (final modelName in modelsToTry) {
      try {
        final model = GenerativeModel(
          model: modelName,
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0.4,
          ),
        );
        final res = await model.generateContent([Content.multi(parts)]);
        if (res.text != null && res.text!.isNotEmpty) {
          response = res;
          break;
        }
      } catch (e) {
        lastError = e;
      }
    }

    if (response == null || response.text == null || response.text!.isEmpty) {
      throw lastError ?? Exception('Gemini returned an empty response. Please try again.');
    }

    final raw = response.text;
    if (raw == null || raw.isEmpty) {
      throw Exception('Gemini returned an empty response. Please try again.');
    }

    return _parseResponse(raw);
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  String _buildPrompt(int count, String difficulty, List<String>? selectedTypes, String? customInstruction) {
    String difficultyRules;

    switch (difficulty.toLowerCase()) {
      case 'easy':
        difficultyRules = '''
DIFFICULTY LEVEL: EASY
- Generate simple, direct factual questions directly based on key facts in the document.
- Example: "What country has high corruption?" -> Answer: "Philippines"
''';
        break;
      case 'high':
      case 'hard':
        difficultyRules = '''
DIFFICULTY LEVEL: HIGH
- Generate scenario and example-based questions, but DO NOT provide obvious explanations or hints in the question itself.
- Example: "John sends a suspicious link to Mike." -> Question asks what type of hacking John did (Phishing).
''';
        break;
      case 'extreme':
        difficultyRules = '''
DIFFICULTY LEVEL: EXTREME
- Generate fill-in-the-blank style questions using "_____" in the question text.
- Example: "DDOS can _____ your database." -> Answer: "Spam"
''';
        break;
      case 'medium':
      default:
        difficultyRules = '''
DIFFICULTY LEVEL: MEDIUM
- Generate scenario and example-based questions with clear context.
- Example: "John sends a suspicious link to Mike. What type of hacking did John do?" -> Answer: "Phishing"
''';
        break;
    }

    String instructionSection = '';
    if (customInstruction != null && customInstruction.trim().isNotEmpty) {
      instructionSection = '''
USER CHATBOX INSTRUCTIONS:
"${customInstruction.trim()}"
Follow the above instructions carefully when generating questions.
''';
    }

    // Build allowed types section — flashcard is never a standalone type.
    final allowedTypes = (selectedTypes != null && selectedTypes.isNotEmpty)
        ? selectedTypes.where((t) => t != 'flashcard').toList()
        : ['mcq', 'identification', 'enumeration'];
    final typeDescriptions = {
      'mcq': '"mcq": Multiple choice (4 choices, 1 correct index)',
      'identification': '"identification": Short keyword answer (user types)',
      'enumeration': '"enumeration": List of key terms (comma-separated)',
    };
    final allowedTypeBlock = allowedTypes
        .map((t) => '   - ${typeDescriptions[t] ?? t}')
        .join('\n');

    return '''
You are an expert educational quiz generator.
Analyse the provided document and generate questions based on it.

STRICT MANDATORY RULES:
1. QUANTITY RULE: You MUST generate EXACTLY $count questions in total. Do NOT generate less than $count or more than $count. The array "questions" MUST contain exactly $count items.
2. QUESTION TYPES TO INCLUDE — use ONLY these types:
$allowedTypeBlock

IMPORTANT ANSWER FORMAT RULE FOR IDENTIFICATION & ENUMERATION:
Answers for "identification" and "enumeration" MUST be short keywords, names, or key phrases (1 to 4 words max). NEVER require a full sentence answer.

$difficultyRules

$instructionSection

Return ONLY valid JSON matching this exact schema — no markdown, no conversational explanation outside JSON:

{
  "quiz_title": "<concise title>",
  "quiz_description": "<one-sentence description>",
  "quiz_category": "<subject area>",
  "questions": [
    {
      "type": "mcq",
      "question": "...",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correct_answer_index": 0
    },
    {
      "type": "identification",
      "question": "...",
      "answer": "<short keyword/term>"
    },
    {
      "type": "enumeration",
      "question": "...",
      "items": ["Item 1", "Item 2"]
    }
  ]
}''';
  }

  GeneratedQuizResult _parseResponse(String raw) {
    // Strip any accidental markdown fences.
    final cleaned = raw
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    final Map<String, dynamic> json =
        jsonDecode(cleaned) as Map<String, dynamic>;

    final rawQuestions = (json['questions'] as List<dynamic>);
    final questions = rawQuestions.map((q) {
      final map = q as Map<String, dynamic>;
      final type = (map['type'] as String?)?.toLowerCase() ?? 'mcq';

      // flashcard type is no longer standalone — treat as identification.
      if (type == 'flashcard' || type == 'identification') {
        final ans = (map['answer'] as String?) ?? '';
        return GeneratedQuestion(
          questionText: (map['question'] as String?) ?? '',
          options: [ans],
          correctAnswerIndex: 0,
          isFlashcard: false,
          flashcardBack: ans,
          questionType: 'identification',
        );
      } else if (type == 'enumeration') {
        final rawItems = map['items'] as List<dynamic>?;
        final items = rawItems != null
            ? rawItems.map((e) => e.toString()).toList()
            : [(map['answer'] as String?) ?? ''];
        return GeneratedQuestion(
          questionText: (map['question'] as String?) ?? '',
          options: items,
          correctAnswerIndex: 0,
          isFlashcard: false,
          flashcardBack: items.join(', '),
          questionType: 'enumeration',
        );
      } else {
        // mcq — set flashcardBack to the correct option text automatically.
        final opts = (map['options'] as List<dynamic>?)
                ?.map((o) => o.toString())
                .toList() ??
            ['Option A', 'Option B', 'Option C', 'Option D'];
        final correctIdx = (map['correct_answer_index'] as int?) ?? 0;
        final safeIdx = (correctIdx >= 0 && correctIdx < opts.length) ? correctIdx : 0;
        return GeneratedQuestion(
          questionText: (map['question'] as String?) ?? '',
          options: opts,
          correctAnswerIndex: safeIdx,
          isFlashcard: false,
          flashcardBack: opts.isNotEmpty ? opts[safeIdx] : null,
          questionType: 'mcq',
        );
      }
    }).toList();

    return GeneratedQuizResult(
      title: json['quiz_title'] as String? ?? 'AI Generated Quiz',
      description: json['quiz_description'] as String?,
      category: json['quiz_category'] as String?,
      questions: questions,
    );
  }

  /// Extract plain text from a DOCX file (which is a ZIP of XML files).
  static String _extractDocxText(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final wordDoc = archive.findFile('word/document.xml');
      if (wordDoc == null) return '';
      final xml = utf8.decode(wordDoc.content as List<int>);
      // Extract text between <w:t> tags.
      final matches = RegExp(r'<w:t[^>]*>(.*?)</w:t>').allMatches(xml);
      return matches.map((m) => m.group(1) ?? '').join(' ');
    } catch (_) {
      return '';
    }
  }

  /// Extract plain text from a PPTX file (also a ZIP of XML files).
  /// Each slide lives under ppt/slides/slideN.xml, with visible text
  /// wrapped in `<a:t>` tags. Slides are read in order and separated so
  /// the AI can still tell where one slide ends and the next begins.
  static String _extractPptxText(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      final slideFiles = archive.files
          .where((f) =>
              f.isFile &&
              RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(f.name))
          .toList();

      // Sort numerically (slide2 before slide10, etc.) instead of
      // alphabetically.
      slideFiles.sort((a, b) {
        final na = int.parse(RegExp(r'\d+').firstMatch(a.name)!.group(0)!);
        final nb = int.parse(RegExp(r'\d+').firstMatch(b.name)!.group(0)!);
        return na.compareTo(nb);
      });

      final buffer = StringBuffer();
      for (var i = 0; i < slideFiles.length; i++) {
        final xml = utf8.decode(slideFiles[i].content as List<int>);
        final matches = RegExp(r'<a:t[^>]*>(.*?)</a:t>').allMatches(xml);
        final slideText = matches.map((m) => m.group(1) ?? '').join(' ');
        if (slideText.trim().isNotEmpty) {
          buffer.writeln('Slide ${i + 1}: $slideText');
        }
      }
      return buffer.toString();
    } catch (_) {
      return '';
    }
  }

  /// Convert a [GeneratedQuizResult] into domain models ready to save.
  static (QuizModel, List<QuestionModel>) toModels(
    GeneratedQuizResult result,
    String userId,
    String quizId,
  ) {
    final now = DateTime.now();
    final questions = result.questions.asMap().entries.map((e) {
      final GeneratedQuestion q = e.value;
      final qId = '${quizId}_q${e.key}';
      return QuestionModel(
        id: qId,
        quizId: quizId,
        questionText: q.questionText,
        options: q.options,
        correctAnswerIndex: q.correctAnswerIndex,
        isFlashcard: q.isFlashcard,
        flashcardBack: q.flashcardBack,
        questionType: q.questionType,
        createdAt: now,
      );
    }).toList();

    final quiz = QuizModel(
      id: quizId,
      userId: userId,
      title: result.title,
      description: result.description,
      category: result.category,
      questionIds: questions.map((q) => q.id).toList(),
      createdAt: now,
    );

    return (quiz, questions);
  }
}