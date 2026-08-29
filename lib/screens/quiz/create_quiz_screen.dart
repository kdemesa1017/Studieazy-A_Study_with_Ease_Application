import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/quiz_provider.dart';
import '../../providers/connectivity_provider.dart';

// ── Question type enum ────────────────────────────────────────────────────────

enum QuizMode { mcq, enumeration, identification, combine }

extension QuizModeX on QuizMode {
  String get label {
    switch (this) {
      case QuizMode.combine:
        return 'Combine';
      case QuizMode.mcq:
        return 'Quiz';
      case QuizMode.enumeration:
        return 'Enumeration';
      case QuizMode.identification:
        return 'Identification (Best for Flashcard)';
    }
  }

  String get description {
    switch (this) {
      case QuizMode.combine:
        return 'Mix MCQ, Identification & Enumeration in one quiz';
      case QuizMode.mcq:
        return 'Test knowledge with multiple choice questions';
      case QuizMode.enumeration:
        return 'List items in the correct order';
      case QuizMode.identification:
        return 'Short keyword answers — perfect for flashcard study mode';
    }
  }

  IconData get icon {
    switch (this) {
      case QuizMode.combine:
        return Icons.merge_type_rounded;
      case QuizMode.mcq:
        return Icons.quiz_rounded;
      case QuizMode.enumeration:
        return Icons.format_list_numbered_rounded;
      case QuizMode.identification:
        return Icons.find_in_page_rounded;
    }
  }

  Color get color {
    switch (this) {
      case QuizMode.combine:
        return const Color(0xFFEC4899);
      case QuizMode.mcq:
        return const Color(0xFF3B82F6);
      case QuizMode.enumeration:
        return const Color(0xFFF97316);
      case QuizMode.identification:
        return const Color(0xFF10B981);
    }
  }

  String get questionType {
    switch (this) {
      case QuizMode.combine:
        return 'mcq'; // placeholder; each question has its own type
      case QuizMode.mcq:
        return 'mcq';
      case QuizMode.enumeration:
        return 'enumeration';
      case QuizMode.identification:
        return 'identification';
    }
  }
}

// ── Question data model ───────────────────────────────────────────────────────

class QuestionFormData {
  final TextEditingController questionController = TextEditingController();
  // Identification answer
  final TextEditingController backController = TextEditingController();
  // MCQ options
  final List<TextEditingController> options = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  // Enumeration items (dynamic)
  List<TextEditingController> enumItems = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  int correctAnswerIndex = 0;
  // Per-question type used when the quiz is in Combine mode
  QuizMode selectedType = QuizMode.mcq;

  void dispose() {
    questionController.dispose();
    backController.dispose();
    for (final c in options) { c.dispose(); }
    for (final c in enumItems) { c.dispose(); }
  }
}

// ── Main Screen ───────────────────────────────────────────────────────────────

class CreateQuizScreen extends ConsumerStatefulWidget {
  const CreateQuizScreen({super.key});

  @override
  ConsumerState<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends ConsumerState<CreateQuizScreen>
    with TickerProviderStateMixin {
  // Step 0=Details, 1=Mode picker, 2=Questions, 3=Review
  int _step = 0;

  // Step 1 — Details
  final _detailsFormKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _categoryController = TextEditingController();

  // Step 2 — Mode
  QuizMode _selectedMode = QuizMode.mcq;

  // Step 3 — Questions
  final List<QuestionFormData> _questions = [];

  bool _isCreating = false;

  static const _primaryColor = Color(0xFF5C4EE8);

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _categoryController.dispose();
    for (final q in _questions) { q.dispose(); }
    super.dispose();
  }

  // ── Navigation helpers ────────────────────────────────────────────────────

  void _goTo(int step) => setState(() => _step = step);

  void _next() {
    if (_step == 0) {
      if (!_detailsFormKey.currentState!.validate()) return;
      _goTo(1);
    } else if (_step == 1) {
      if (_questions.isEmpty) _questions.add(QuestionFormData());
      _goTo(2);
    } else if (_step == 2) {
      if (!_validateQuestions()) return;
      _goTo(3);
    } else {
      _createQuiz();
    }
  }

  void _back() {
    if (_step == 0) {
      context.pop();
    } else {
      _goTo(_step - 1);
    }
  }

  // ── Validation ────────────────────────────────────────────────────────────

  bool _validateQuestions() {
    if (_questions.isEmpty) {
      _showSnack('Add at least one question.', isError: true);
      return false;
    }
    for (var i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final n = i + 1;
      if (q.questionController.text.trim().isEmpty) {
        _showSnack('Enter text for Question $n.', isError: true);
        return false;
      }
      // Determine effective type (per-question for combine, global otherwise)
      final effectiveType = _selectedMode == QuizMode.combine
          ? q.selectedType
          : _selectedMode;
      switch (effectiveType) {
        case QuizMode.mcq:
          if (q.options.any((o) => o.text.trim().isEmpty)) {
            _showSnack('Fill all 4 options for Question $n.', isError: true);
            return false;
          }
        case QuizMode.enumeration:
          final validItems =
              q.enumItems.where((c) => c.text.trim().isNotEmpty).toList();
          if (validItems.isEmpty) {
            _showSnack('Add at least one item for Question $n.', isError: true);
            return false;
          }
        case QuizMode.identification:
          if (q.backController.text.trim().isEmpty) {
            _showSnack('Enter the answer for Question $n.', isError: true);
            return false;
          }
        case QuizMode.combine:
          break; // handled above
      }
    }
    return true;
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : _primaryColor,
      ),
    );
  }

  // ── Create quiz ───────────────────────────────────────────────────────────

  Future<void> _createQuiz() async {
    setState(() => _isCreating = true);

    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      setState(() => _isCreating = false);
      return;
    }

    try {
      final quiz = await ref
          .read(userQuizzesProvider(user.id).notifier)
          .createQuiz(
            title: _titleController.text.trim(),
            description:
                _descController.text.trim().isEmpty
                    ? null
                    : _descController.text.trim(),
            category:
                _categoryController.text.trim().isEmpty
                    ? null
                    : _categoryController.text.trim(),
          );

      for (final q in _questions) {
        List<String> options;
        String? flashcardBack;
        String questionType;
        bool isFlashcard = false;

        // Determine effective type per question (combine) or global
        final effectiveType = _selectedMode == QuizMode.combine
            ? q.selectedType
            : _selectedMode;

        switch (effectiveType) {
          case QuizMode.identification:
            options = [q.backController.text.trim()];
            flashcardBack = q.backController.text.trim();
            questionType = 'identification';
          case QuizMode.enumeration:
            options = q.enumItems
                .map((c) => c.text.trim())
                .where((t) => t.isNotEmpty)
                .toList();
            flashcardBack = options.join(', ');
            questionType = 'enumeration';
          case QuizMode.mcq:
          case QuizMode.combine:
            options = q.options.map((c) => c.text.trim()).toList();
            final correctIdx = q.correctAnswerIndex;
            flashcardBack = (correctIdx >= 0 && correctIdx < options.length)
                ? options[correctIdx]
                : null;
            questionType = 'mcq';
        }

        await ref
            .read(userQuizzesProvider(user.id).notifier)
            .addQuestion(
              quizId: quiz.id,
              questionText: q.questionController.text.trim(),
              options: options,
              correctAnswerIndex:
                  (effectiveType == QuizMode.mcq || _selectedMode == QuizMode.combine && q.selectedType == QuizMode.mcq)
                      ? q.correctAnswerIndex
                      : 0,
              isFlashcard: isFlashcard,
              flashcardBack: flashcardBack,
              questionType: questionType,
            );
      }

      setState(() => _isCreating = false);

      final isOnline =
          await ref.read(connectivityServiceProvider).isOnline;
      if (mounted) {
        _showSnack(
          isOnline
              ? 'Quiz created successfully!'
              : 'Saved offline — will sync when back online.',
        );
        context.go('/quiz/${quiz.id}');
      }
    } catch (_) {
      setState(() => _isCreating = false);
      _showSnack('Failed to create quiz. Please try again.', isError: true);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F121E) : const Color(0xFFF8F8FC);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder:
                    (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.05, 0),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: _buildCurrentStep(isDark),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header with step indicator ────────────────────────────────────────────

  Widget _buildHeader(bool isDark) {
    final headerBg = isDark ? const Color(0xFF1A1F38) : Colors.white;
    final iconBg = isDark ? const Color(0xFF1E2337) : Colors.grey.shade100;
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subtitleColor = isDark ? Colors.white54 : Colors.grey.shade500;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      color: headerBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _back,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create a Quiz',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    Text(
                      _stepSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStepBar(isDark),
          const SizedBox(height: 0),
        ],
      ),
    );
  }

  String get _stepSubtitle {
    switch (_step) {
      case 0:
        return 'Step 1 of 3  ·  Quiz Details';
      case 1:
        return 'Step 2 of 3  ·  Choose Mode';
      case 2:
        return 'Step 2 of 3  ·  Add Questions';
      case 3:
        return 'Step 3 of 3  ·  Review';
      default:
        return '';
    }
  }

  Widget _buildStepBar(bool isDark) {
    final displayStep = _step == 0 ? 0 : (_step <= 2 ? 1 : 2);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          _StepPill(number: 1, label: 'Details', active: displayStep == 0, done: displayStep > 0, isDark: isDark),
          _StepLine(active: displayStep >= 1, isDark: isDark),
          _StepPill(number: 2, label: 'Questions', active: displayStep == 1, done: displayStep > 1, isDark: isDark),
          _StepLine(active: displayStep >= 2, isDark: isDark),
          _StepPill(number: 3, label: 'Review', active: displayStep == 2, done: false, isDark: isDark),
        ],
      ),
    );
  }

  // ── Step routing ──────────────────────────────────────────────────────────

  Widget _buildCurrentStep(bool isDark) {
    switch (_step) {
      case 0:
        return _buildDetailsStep(isDark);
      case 1:
        return _buildModeStep(isDark);
      case 2:
        return _buildQuestionsStep(isDark);
      case 3:
        return _buildReviewStep(isDark);
      default:
        return const SizedBox();
    }
  }

  // ── Step 1: Details ───────────────────────────────────────────────────────

  Widget _buildDetailsStep(bool isDark) {
    final chipBg = isDark ? const Color(0xFF1E2337) : Colors.white;
    final chipBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300;
    final chipText = isDark ? Colors.white70 : Colors.grey.shade700;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _detailsFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Quiz Title', isDark: isDark, required: true),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1A1A2E)),
                    decoration: _inputDeco('Enter quiz title', Icons.title_rounded, isDark),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Please enter a title'
                            : null,
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel('Description', isDark: isDark),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descController,
                    maxLines: 3,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1A1A2E)),
                    decoration: _inputDeco(
                      'Enter a short description (optional)',
                      Icons.description_outlined,
                      isDark,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel('Category', isDark: isDark),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _categoryController,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1A1A2E)),
                    decoration: _inputDeco(
                      'e.g. Science, History, Math',
                      Icons.category_outlined,
                      isDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Category suggestions
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      'Science',
                      'Math',
                      'History',
                      'English',
                      'Filipino',
                      'Technology',
                    ].map((cat) {
                      return ActionChip(
                        label: Text(cat),
                        onPressed: () =>
                            setState(() => _categoryController.text = cat),
                        backgroundColor: chipBg,
                        side: BorderSide(color: chipBorder),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: chipText,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildBottomBar(primaryLabel: 'Continue', onPrimary: _next, isDark: isDark),
      ],
    );
  }

  // ── Step 2a: Mode picker ──────────────────────────────────────────────────

  Widget _buildModeStep(bool isDark) {
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subtitleColor = isDark ? Colors.white54 : Colors.grey.shade500;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose Question Mode',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select the type of questions for your quiz',
                  style: TextStyle(fontSize: 13, color: subtitleColor),
                ),
                const SizedBox(height: 20),
                // Show all modes EXCEPT combine first, then combine last
                ...[QuizMode.mcq, QuizMode.identification, QuizMode.enumeration, QuizMode.combine]
                    .map((mode) => _buildModeCard(mode, isDark)),
              ],
            ),
          ),
        ),
        _buildBottomBar(
          primaryLabel: 'Continue',
          onPrimary: _next,
          showBack: true,
          onBack: _back,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildModeCard(QuizMode mode, bool isDark) {
    final isSelected = _selectedMode == mode;
    final cardBg = isDark ? const Color(0xFF1A1F38) : Colors.white;
    final borderColor = isSelected
        ? mode.color
        : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200);
    final titleColor = isSelected
        ? mode.color
        : (isDark ? Colors.white : const Color(0xFF1A1A2E));
    final subtitleColor = isDark ? Colors.white54 : Colors.grey.shade500;

    return GestureDetector(
      onTap: () => setState(() => _selectedMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: mode.color.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: mode.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(mode.icon, color: mode.color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mode.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? mode.color
                      : (isDark ? Colors.white38 : Colors.grey.shade300),
                  width: 2,
                ),
                color: isSelected ? mode.color : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 2b: Add Questions ────────────────────────────────────────────────

  Widget _buildQuestionsStep(bool isDark) {
    final mode = _selectedMode;
    final topBarBg = isDark ? const Color(0xFF1A1F38) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subtitleColor = isDark ? Colors.white54 : Colors.grey.shade500;

    return Column(
      children: [
        // Mode badge bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          color: topBarBg,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: mode.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(mode.icon, color: mode.color, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      mode.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: mode.color,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${_questions.length} question${_questions.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 13,
                  color: subtitleColor,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Add Questions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Add at least one question to your quiz',
                style: TextStyle(fontSize: 13, color: subtitleColor),
              ),
              const SizedBox(height: 16),
              ..._questions.asMap().entries.map((e) {
                return _buildQuestionCard(e.key, e.value, mode, isDark);
              }),
              const SizedBox(height: 8),
              _buildAddQuestionButton(isDark),
            ],
          ),
        ),
        _buildBottomBar(
          primaryLabel: 'Continue',
          onPrimary: _next,
          showBack: true,
          onBack: _back,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildAddQuestionButton(bool isDark) {
    final btnBg = isDark ? const Color(0xFF1A1F38) : Colors.white;
    return GestureDetector(
      onTap: () => setState(() => _questions.add(QuestionFormData())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: btnBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _primaryColor.withValues(alpha: 0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_circle_outline, color: _primaryColor, size: 20),
            const SizedBox(width: 8),
            const Text(
              '+ Add Question',
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(int index, QuestionFormData q, QuizMode mode, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1A1F38) : Colors.white;
    final headerBg = isDark ? const Color(0xFF161A30) : Colors.grey.shade50;
    final headerBorder = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100;
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    // In combine mode, use per-question type; otherwise use the global mode.
    final effectiveType = mode == QuizMode.combine ? q.selectedType : mode;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: headerBorder)),
            ),
            child: Row(
              children: [
                Text(
                  'Question ${index + 1}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(width: 8),
                // In combine mode: show a type-switcher dropdown; otherwise show static badge
                if (mode == QuizMode.combine)
                  _buildCombineTypeSwitcher(q, isDark)
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: effectiveType.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      effectiveType.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: effectiveType.color,
                      ),
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() {
                    q.dispose();
                    _questions.removeAt(index);
                  }),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50.withValues(alpha: isDark ? 0.2 : 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: Colors.red.shade400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Question', isDark: isDark),
                const SizedBox(height: 6),
                TextFormField(
                  controller: q.questionController,
                  maxLines: 2,
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1A1A2E)),
                  decoration: _inputDeco(
                    effectiveType == QuizMode.enumeration
                        ? 'Enter your question/instruction'
                        : effectiveType == QuizMode.identification
                        ? 'What is this?'
                        : 'Enter your question',
                    Icons.help_outline_rounded,
                    isDark,
                  ),
                ),
                const SizedBox(height: 14),
                _buildAnswerSection(index, q, effectiveType, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Small inline type-switcher shown in Combine mode question card header.
  Widget _buildCombineTypeSwitcher(QuestionFormData q, bool isDark) {
    final types = [QuizMode.mcq, QuizMode.identification, QuizMode.enumeration];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: types.map((t) {
        final isActive = q.selectedType == t;
        return GestureDetector(
          onTap: () => setState(() => q.selectedType = t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isActive ? t.color.withValues(alpha: 0.18) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive ? t.color : (isDark ? Colors.white24 : Colors.grey.shade300),
                width: 1,
              ),
            ),
            child: Text(
              t.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                color: isActive ? t.color : (isDark ? Colors.white38 : Colors.grey.shade500),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAnswerSection(int index, QuestionFormData q, QuizMode mode, bool isDark) {
    switch (mode) {
      case QuizMode.identification:
        final uploadBg = isDark ? const Color(0xFF161A30) : Colors.grey.shade50;
        final uploadBorder = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200;
        final uploadIcon = isDark ? Colors.white38 : Colors.grey.shade400;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel('Add Image (Optional)', isDark: isDark),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _showSnack('Image upload — Coming Soon!'),
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: uploadBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: uploadBorder),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 32,
                      color: uploadIcon,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap to upload image',
                      style: TextStyle(
                        fontSize: 12,
                        color: uploadIcon,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _fieldLabel('Answer', isDark: isDark),
            const SizedBox(height: 6),
            TextFormField(
              controller: q.backController,
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1A1A2E)),
              decoration: _inputDeco(
                'Enter the correct answer',
                Icons.check_circle_outline_rounded,
                isDark,
              ),
            ),
          ],
        );

      case QuizMode.enumeration:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _fieldLabel('Items', isDark: isDark),
                const Spacer(),
                Text(
                  'Drag to reorder',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade400),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = q.enumItems.removeAt(oldIndex);
                  q.enumItems.insert(newIndex, item);
                });
              },
              children: q.enumItems.asMap().entries.map((entry) {
                final i = entry.key;
                final ctrl = entry.value;
                return Padding(
                  key: ValueKey('enum_${index}_$i'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: ctrl,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1A1A2E)),
                          decoration: _inputDeco('Item ${i + 1}', null, isDark),
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (q.enumItems.length > 1)
                        IconButton(
                          icon: Icon(
                            Icons.remove_circle_outline,
                            color: Colors.red.shade300,
                            size: 20,
                          ),
                          onPressed: () => setState(() {
                            ctrl.dispose();
                            q.enumItems.removeAt(i);
                          }),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.drag_handle_rounded,
                        color: isDark ? Colors.white38 : Colors.grey,
                        size: 20,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            TextButton.icon(
              onPressed: () =>
                  setState(() => q.enumItems.add(TextEditingController())),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('+ Add Item'),
              style: TextButton.styleFrom(
                foregroundColor: _primaryColor,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        );

      case QuizMode.mcq:
      case QuizMode.combine: // combine falls through to mcq UI (per-question type already resolved)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel('Options', isDark: isDark),
            const SizedBox(height: 6),
            ...q.options.asMap().entries.map((entry) {
              final i = entry.key;
              final ctrl = entry.value;
              final isCorrect = q.correctAnswerIndex == i;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => q.correctAnswerIndex = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isCorrect
                                ? _primaryColor
                                : (isDark ? Colors.white38 : Colors.grey.shade300),
                            width: 2,
                          ),
                          color: isCorrect ? _primaryColor : Colors.transparent,
                        ),
                        child: isCorrect
                            ? const Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: ctrl,
                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1A1A2E)),
                        decoration: _inputDeco(
                          i == 0 ? 'Correct answer' : 'Option ${i + 1}',
                          null,
                          isDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                    ),
                  ],
                ),
              );
            }),
          ],
        );
    }
  }

  // ── Step 3: Review ────────────────────────────────────────────────────────

  Widget _buildReviewStep(bool isDark) {
    final totalQ = _questions.length;
    final cardBg = isDark ? const Color(0xFF1A1F38) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subtitleColor = isDark ? Colors.white54 : Colors.grey.shade500;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review Your Quiz',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Please review your quiz details before creating',
                  style: TextStyle(fontSize: 13, color: subtitleColor),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
                    ),
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Column(
                    children: [
                      _reviewRow(
                        Icons.title_rounded,
                        'Title',
                        _titleController.text.trim().isEmpty
                            ? '—'
                            : _titleController.text.trim(),
                        onEdit: () => _goTo(0),
                        isDark: isDark,
                      ),
                      _divider(isDark),
                      _reviewRow(
                        Icons.description_outlined,
                        'Description',
                        _descController.text.trim().isEmpty
                            ? '—'
                            : _descController.text.trim(),
                        onEdit: () => _goTo(0),
                        isDark: isDark,
                      ),
                      _divider(isDark),
                      _reviewRow(
                        Icons.category_outlined,
                        'Category',
                        _categoryController.text.trim().isEmpty
                            ? '—'
                            : _categoryController.text.trim(),
                        onEdit: () => _goTo(0),
                        isDark: isDark,
                      ),
                      _divider(isDark),
                      _reviewRow(
                        _selectedMode.icon,
                        'Mode',
                        _selectedMode.label,
                        iconColor: _selectedMode.color,
                        onEdit: () => _goTo(1),
                        isDark: isDark,
                      ),
                      _divider(isDark),
                      _reviewRow(
                        Icons.help_outline_rounded,
                        'Total Questions',
                        '$totalQ question${totalQ == 1 ? '' : 's'}',
                        onEdit: () => _goTo(2),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildBottomBar(
          primaryLabel: '✓  Create Quiz',
          onPrimary: _isCreating ? null : _next,
          showBack: true,
          onBack: _back,
          isPrimary: true,
          isLoading: _isCreating,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _reviewRow(
    IconData icon,
    String label,
    String value, {
    required VoidCallback onEdit,
    required bool isDark,
    Color? iconColor,
  }) {
    final labelColor = isDark ? Colors.white38 : Colors.grey.shade400;
    final valueColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (iconColor ?? _primaryColor).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: iconColor ?? _primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: labelColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Edit',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) => Divider(
        height: 1,
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100,
        indent: 16,
        endIndent: 16,
      );

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar({
    required String primaryLabel,
    required VoidCallback? onPrimary,
    required bool isDark,
    bool showBack = false,
    VoidCallback? onBack,
    bool isPrimary = false,
    bool isLoading = false,
  }) {
    final barBg = isDark ? const Color(0xFF1A1F38) : Colors.white;
    final topBorder = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100;
    final backBorder = isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey.shade300;
    final backText = isDark ? Colors.white70 : Colors.black87;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: barBg,
        border: Border(top: BorderSide(color: topBorder)),
      ),
      child: Row(
        children: [
          if (showBack) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: backBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Back',
                  style: TextStyle(fontWeight: FontWeight.w600, color: backText),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: showBack ? 2 : 1,
            child: ElevatedButton(
              onPressed: onPrimary,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 4,
                shadowColor: _primaryColor.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      primaryLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper widgets ────────────────────────────────────────────────────────

  Widget _sectionLabel(String text, {required bool isDark, bool required = false}) {
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
        ),
        if (required)
          Text(
            ' *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.red.shade400,
            ),
          ),
      ],
    );
  }

  Widget _fieldLabel(String text, {required bool isDark}) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white54 : Colors.grey.shade600,
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData? icon, bool isDark) {
    final fillColor = isDark ? const Color(0xFF1E2337) : const Color(0xFFF9F9FC);
    final hintColor = isDark ? Colors.white38 : Colors.grey.shade400;
    final iconColor = isDark ? Colors.white38 : Colors.grey.shade400;
    final borderSide = BorderSide(
      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: hintColor, fontSize: 13),
      prefixIcon:
          icon != null ? Icon(icon, size: 18, color: iconColor) : null,
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: borderSide,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: borderSide,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    );
  }
}

// ── Step pill widget ──────────────────────────────────────────────────────────

class _StepPill extends StatelessWidget {
  final int number;
  final String label;
  final bool active;
  final bool done;
  final bool isDark;

  const _StepPill({
    required this.number,
    required this.label,
    required this.active,
    required this.done,
    required this.isDark,
  });

  static const _primary = Color(0xFF5C4EE8);

  @override
  Widget build(BuildContext context) {
    final Color inactiveBg = isDark ? const Color(0xFF1E2337) : Colors.grey.shade200;
    final Color bgColor = done ? _primary : (active ? _primary : inactiveBg);
    final Color textColor = (done || active)
        ? Colors.white
        : (isDark ? Colors.white38 : Colors.grey.shade400);
    final Color labelColor = active
        ? _primary
        : (done
            ? (isDark ? Colors.white70 : Colors.grey.shade600)
            : (isDark ? Colors.white38 : Colors.grey.shade400));

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text(
                    '$number',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.normal,
            color: labelColor,
          ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool active;
  final bool isDark;

  const _StepLine({required this.active, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.grey.shade200;

    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: active
                ? [const Color(0xFF5C4EE8), const Color(0xFF5C4EE8)]
                : [inactiveColor, inactiveColor],
          ),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
