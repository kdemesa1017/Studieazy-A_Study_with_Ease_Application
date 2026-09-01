class QuestionModel {
  final String id;
  final String quizId;
  final String questionText;
  final List<String> options;
  final int correctAnswerIndex;
  final bool isFlashcard;
  final String? flashcardBack;
  final String questionType; // 'mcq', 'flashcard', 'identification', 'enumeration'
  final String? imageUrl;
  final DateTime createdAt;

  QuestionModel({
    required this.id,
    required this.quizId,
    required this.questionText,
    required this.options,
    required this.correctAnswerIndex,
    this.isFlashcard = false,
    this.flashcardBack,
    this.questionType = 'mcq',
    this.imageUrl,
    required this.createdAt,
  });

  bool get isIdentification => questionType == 'identification';
  bool get isEnumeration => questionType == 'enumeration';
  bool get isMultipleChoice =>
      questionType == 'mcq' ||
      (!isFlashcard && !isIdentification && !isEnumeration);

  /// Returns the formatted answer string suitable for displaying on a flashcard or answer key.
  String get displayAnswer {
    if (isEnumeration) {
      if (options.length > 1) {
        return options.map((e) => '• ${e.trim()}').join('\n');
      } else if (options.length == 1 && options.first.contains(',')) {
        return options.first
            .split(',')
            .map((e) => '• ${e.trim()}')
            .where((e) => e.length > 2)
            .join('\n');
      } else if (flashcardBack != null && flashcardBack!.trim().isNotEmpty) {
        if (flashcardBack!.contains(',')) {
          return flashcardBack!
              .split(',')
              .map((e) => '• ${e.trim()}')
              .where((e) => e.length > 2)
              .join('\n');
        }
        return flashcardBack!.trim();
      } else if (options.isNotEmpty) {
        return options.first.trim();
      }
    }
    if (flashcardBack != null && flashcardBack!.trim().isNotEmpty) {
      return flashcardBack!.trim();
    }
    if (options.isNotEmpty) {
      if (correctAnswerIndex >= 0 && correctAnswerIndex < options.length) {
        return options[correctAnswerIndex].trim();
      }
      return options.map((e) => '• ${e.trim()}').join('\n');
    }
    return '';
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'quizId': quizId,
      'questionText': questionText,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
      'isFlashcard': isFlashcard,
      'flashcardBack': flashcardBack,
      'questionType': questionType,
      if (imageUrl != null && imageUrl!.isNotEmpty) 'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory QuestionModel.fromFirestore(Map<String, dynamic> data) {
    final rawIsFlashcard = data['isFlashcard'] as bool? ?? false;
    final rawType =
        data['questionType'] as String? ??
        (rawIsFlashcard ? 'flashcard' : 'mcq');
    return QuestionModel(
      id: data['id'] as String,
      quizId: data['quizId'] as String,
      questionText: data['questionText'] as String,
      options: List<String>.from(data['options'] as List? ?? []),
      correctAnswerIndex: data['correctAnswerIndex'] as int? ?? 0,
      isFlashcard: rawIsFlashcard || rawType == 'flashcard',
      flashcardBack: data['flashcardBack'] as String?,
      questionType: rawType,
      imageUrl: data['imageUrl'] as String?,
      createdAt: DateTime.parse(data['createdAt'] as String),
    );
  }

  QuestionModel copyWith({
    String? id,
    String? quizId,
    String? questionText,
    List<String>? options,
    int? correctAnswerIndex,
    bool? isFlashcard,
    String? flashcardBack,
    String? questionType,
    String? imageUrl,
    DateTime? createdAt,
  }) {
    return QuestionModel(
      id: id ?? this.id,
      quizId: quizId ?? this.quizId,
      questionText: questionText ?? this.questionText,
      options: options ?? this.options,
      correctAnswerIndex: correctAnswerIndex ?? this.correctAnswerIndex,
      isFlashcard: isFlashcard ?? this.isFlashcard,
      flashcardBack: flashcardBack ?? this.flashcardBack,
      questionType: questionType ?? this.questionType,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
