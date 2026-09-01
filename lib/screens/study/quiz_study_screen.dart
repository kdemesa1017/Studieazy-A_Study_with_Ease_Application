import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/quiz_provider.dart';
import '../../models/question_model.dart';
import '../../widgets/skeleton_loader.dart';

class QuizStudyScreen extends ConsumerStatefulWidget {
  final String quizId;

  const QuizStudyScreen({super.key, required this.quizId});

  @override
  ConsumerState<QuizStudyScreen> createState() => _QuizStudyScreenState();
}

class _QuizStudyScreenState extends ConsumerState<QuizStudyScreen> {
  bool _isLoading = true;
  List<QuestionModel> _questions = [];
  List<QuestionModel> _shuffledQuestions = [];
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedAnswer;
  bool _hasAnswered = false;
  List<int> _userAnswers = [];

  // For Identification questions
  final TextEditingController _textInputController = TextEditingController();
  bool? _isTextAnswerCorrect;

  // For Enumeration questions — one controller per expected answer item
  List<TextEditingController> _enumControllers = [];
  List<bool> _enumCorrectness = [];

  // Auto advance timer
  Timer? _autoAdvanceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuestions());
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _textInputController.dispose();
    for (final c in _enumControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final (_, questions) = await ref
        .read(userQuizzesProvider(user.id).notifier)
        .getQuizWithQuestions(widget.quizId);

    // Filter out flashcards for quiz mode
    final quizQuestions = questions.where((q) => !q.isFlashcard).toList();

    // Pre-build enum controllers for the first question
    final firstQ = quizQuestions.isNotEmpty ? quizQuestions.first : null;
    final initialEnumControllers =
        (firstQ != null && firstQ.isEnumeration)
            ? List.generate(
                firstQ.options.length,
                (_) => TextEditingController(),
              )
            : <TextEditingController>[];

    if (mounted) {
      setState(() {
        _questions = quizQuestions;
        // Keep original creator order by default — do not auto-shuffle
        _shuffledQuestions = List<QuestionModel>.from(quizQuestions);
        _enumControllers = initialEnumControllers;
        _isLoading = false;
      });
    }
  }

  void _startAutoAdvanceTimer() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _hasAnswered) {
        _nextQuestion();
      }
    });
  }

  void _shuffleQuestionsList() {
    setState(() {
      _shuffledQuestions.shuffle();
      _currentIndex = 0;
      _score = 0;
      _hasAnswered = false;
      _selectedAnswer = null;
      _userAnswers.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Questions shuffled!'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _selectAnswer(int index) {
    if (_hasAnswered) return;

    setState(() {
      _selectedAnswer = index;
      _hasAnswered = true;
      _userAnswers.add(index);

      final currentQuestion = _shuffledQuestions[_currentIndex];
      if (index == currentQuestion.correctAnswerIndex) {
        _score++;
      }
    });

    _startAutoAdvanceTimer();
  }

  void _submitTextAnswer() {
    if (_hasAnswered) return;
    final currentQuestion = _shuffledQuestions[_currentIndex];

    bool isCorrect = false;

    if (currentQuestion.isIdentification) {
      final userText = _textInputController.text.trim();
      if (userText.isEmpty) return;
      final expected =
          (currentQuestion.flashcardBack ??
                  currentQuestion.options.firstOrNull ??
                  '')
              .trim();
      final normUser =
          userText.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
      final normExpected =
          expected.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
      isCorrect = normUser == normExpected || normExpected.contains(normUser);
    } else if (currentQuestion.isEnumeration) {
      final expectedItems = currentQuestion.options;
      // Per-field evaluation
      final correctness = <bool>[];
      int matches = 0;
      for (var i = 0; i < expectedItems.length; i++) {
        final userVal =
            i < _enumControllers.length
                ? _enumControllers[i].text.trim().toLowerCase()
                : '';
        final normExp =
            expectedItems[i].trim().toLowerCase().replaceAll(
              RegExp(r'[^\w\s]'),
              '',
            );
        final normUser = userVal.replaceAll(RegExp(r'[^\w\s]'), '').trim();
        final match =
            normUser.isNotEmpty &&
            (normUser == normExp || normExp.contains(normUser));
        correctness.add(match);
        if (match) matches++;
      }
      _enumCorrectness = correctness;
      isCorrect =
          matches > 0 && matches >= (expectedItems.length / 2).ceil();
    }

    setState(() {
      _hasAnswered = true;
      _isTextAnswerCorrect = isCorrect;
      if (isCorrect) _score++;
    });

    _startAutoAdvanceTimer();
  }

  void _nextQuestion() {
    _autoAdvanceTimer?.cancel();
    if (_currentIndex < _shuffledQuestions.length - 1) {
      // Rebuild enum controllers for the upcoming question
      final nextQuestion = _shuffledQuestions[_currentIndex + 1];
      final newControllers = nextQuestion.isEnumeration
          ? List.generate(
              nextQuestion.options.length,
              (_) => TextEditingController(),
            )
          : <TextEditingController>[];

      setState(() {
        _currentIndex++;
        _selectedAnswer = null;
        _hasAnswered = false;
        _isTextAnswerCorrect = null;
        _textInputController.clear();
        // Dispose old enum controllers, replace with new
        for (final c in _enumControllers) { c.dispose(); }
        _enumControllers = newControllers;
        _enumCorrectness = [];
      });
    } else {
      _showResults();
    }
  }

  Future<void> _showResults() async {
    _autoAdvanceTimer?.cancel();
    final total = _shuffledQuestions.length;
    final percentage = total > 0 ? (_score / total * 100).round() : 0;

    // Update quiz stats
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user != null) {
      await ref
          .read(userQuizzesProvider(user.id).notifier)
          .updateQuizStats(widget.quizId, _score, total);
    }

    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              title: const Text('Quiz Complete!'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Score Circle
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors:
                            percentage >= 70
                                ? [Colors.green, Colors.green.shade600]
                                : percentage >= 50
                                ? [Colors.orange, Colors.orange.shade600]
                                : [Colors.red, Colors.red.shade600],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$percentage%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$_score/$total',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    percentage >= 70
                        ? 'Excellent work!'
                        : percentage >= 50
                        ? 'Good job!'
                        : 'Keep practicing!',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/study');
                  },
                  child: const Text('Done'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _restartQuiz();
                  },
                  child: const Text('Try Again'),
                ),
              ],
            ),
      );
    }
  }

  void _restartQuiz() {
    _autoAdvanceTimer?.cancel();
    // Rebuild enum controllers for the first question
    final firstQuestion = _shuffledQuestions.isNotEmpty
        ? _shuffledQuestions[0]
        : null;
    final newControllers = (firstQuestion != null && firstQuestion.isEnumeration)
        ? List.generate(
            firstQuestion.options.length,
            (_) => TextEditingController(),
          )
        : <TextEditingController>[];
    setState(() {
      _currentIndex = 0;
      _score = 0;
      _selectedAnswer = null;
      _hasAnswered = false;
      _isTextAnswerCorrect = null;
      _userAnswers = [];
      _textInputController.clear();
      for (final c in _enumControllers) { c.dispose(); }
      _enumControllers = newControllers;
      _enumCorrectness = [];
      _shuffledQuestions.shuffle();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        resizeToAvoidBottomInset: false,
        body: PageSkeleton(),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(title: const Text('Quiz Mode')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.quiz, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No quiz questions available',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Add multiple-choice, identification, or enumeration questions to this quiz',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final currentQuestion = _shuffledQuestions[_currentIndex];
    final progress = (_currentIndex + 1) / _shuffledQuestions.length;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Quiz Mode'),
        actions: [
          Center(
            child: Text(
              '${_currentIndex + 1}/${_shuffledQuestions.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: _shuffleQuestionsList,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  Icons.shuffle_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress Bar
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            minHeight: 6,
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Score & Question Type Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.emoji_events,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Score: $_score',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          currentQuestion.isIdentification
                              ? 'Identification'
                              : currentQuestion.isEnumeration
                                  ? 'Enumeration'
                                  : 'Multiple Choice',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Question Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      currentQuestion.questionText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Options or Text Input based on Question Type
                  if (currentQuestion.isIdentification || currentQuestion.isEnumeration)
                    _buildTextAnswerInput(currentQuestion)
                  else
                    ...currentQuestion.options.asMap().entries.map((entry) {
                      final index = entry.key;
                      final option = entry.value;
                      return _buildOptionCard(
                        index,
                        option,
                        currentQuestion.correctAnswerIndex,
                      );
                    }),

                  const SizedBox(height: 24),

                  // Auto advance notice & Next Button
                  if (_hasAnswered) ...[
                    Center(
                      child: Text(
                        'Moving to next question in 3s...',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _nextQuestion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          _currentIndex < _shuffledQuestions.length - 1
                              ? 'Next Question'
                              : 'See Results',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextAnswerInput(QuestionModel question) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // ── Identification ───────────────────────────────────────────────────────
    if (question.isIdentification) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Type your answer (short key term/keyword only):',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textInputController,
            enabled: !_hasAnswered,
            minLines: 1,
            maxLines: 4,
            keyboardType: TextInputType.multiline,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Type your answer here...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '• Enter key terms or definition. Text automatically wraps to the next line.',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 16),
          if (!_hasAnswered)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitTextAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Submit Answer',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          if (_hasAnswered) ...[
            const SizedBox(height: 12),
            _buildAnswerFeedback(
              isDarkMode: isDarkMode,
              isCorrect: _isTextAnswerCorrect ?? false,
              expectedLabel:
                  'Expected: ${question.flashcardBack ?? question.options.firstOrNull ?? ''}',
            ),
          ],
        ],
      );
    }

    // ── Enumeration ──────────────────────────────────────────────────────────
    // Show one TextField per expected answer item
    final expectedItems = question.options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fill in each item (${expectedItems.length} answer${expectedItems.length > 1 ? 's' : ''} required):',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(expectedItems.length, (i) {
          // After answering, colour each field border based on correctness
          Color borderColor = Theme.of(context).colorScheme.outline.withValues(alpha: 0.5);
          if (_hasAnswered && i < _enumCorrectness.length) {
            borderColor = _enumCorrectness[i] ? Colors.green : Colors.red;
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller:
                      i < _enumControllers.length ? _enumControllers[i] : null,
                  enabled: !_hasAnswered,
                  minLines: 1,
                  maxLines: 3,
                  keyboardType: TextInputType.multiline,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Item ${i + 1}',
                    hintText: 'e.g., ${expectedItems[i]}',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    suffixIcon: _hasAnswered && i < _enumCorrectness.length
                        ? Icon(
                            _enumCorrectness[i]
                                ? Icons.check_circle
                                : Icons.cancel,
                            color:
                                _enumCorrectness[i] ? Colors.green : Colors.red,
                          )
                        : null,
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        if (!_hasAnswered)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitTextAnswer,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Submit Answers',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        if (_hasAnswered) ...[
          const SizedBox(height: 12),
          _buildAnswerFeedback(
            isDarkMode: isDarkMode,
            isCorrect: _isTextAnswerCorrect ?? false,
            expectedLabel:
                'Expected answers: ${expectedItems.join(', ')}',
          ),
        ],
      ],
    );
  }

  Widget _buildAnswerFeedback({
    required bool isDarkMode,
    required bool isCorrect,
    required String expectedLabel,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCorrect
            ? (isDarkMode
                ? Colors.green.shade900.withValues(alpha: 0.4)
                : Colors.green.shade50)
            : (isDarkMode
                ? Colors.red.shade900.withValues(alpha: 0.4)
                : Colors.red.shade50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: isCorrect ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect ? 'Correct Answer!' : 'Incorrect Answer',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isCorrect ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            expectedLabel,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildOptionCard(int index, String option, int correctIndex) {
    final isSelected = _selectedAnswer == index;
    final isCorrect = index == correctIndex;
    final showCorrect = _hasAnswered && isCorrect;
    final showWrong = _hasAnswered && isSelected && !isCorrect;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    Color backgroundColor;
    Color borderColor;
    Color textColor;
    IconData? trailingIcon;
    Color? iconColor;

    if (showCorrect) {
      backgroundColor =
          isDarkMode
              ? Colors.green.shade900.withValues(alpha: 0.4)
              : Colors.green.shade50;
      borderColor = isDarkMode ? Colors.green.shade400 : Colors.green;
      textColor = isDarkMode ? Colors.green.shade100 : Colors.green.shade900;
      trailingIcon = Icons.check_circle;
      iconColor = isDarkMode ? Colors.green.shade300 : Colors.green;
    } else if (showWrong) {
      backgroundColor =
          isDarkMode
              ? Colors.red.shade900.withValues(alpha: 0.4)
              : Colors.red.shade50;
      borderColor = isDarkMode ? Colors.red.shade400 : Colors.red;
      textColor = isDarkMode ? Colors.red.shade100 : Colors.red.shade900;
      trailingIcon = Icons.cancel;
      iconColor = isDarkMode ? Colors.red.shade300 : Colors.red;
    } else if (isSelected) {
      backgroundColor = Theme.of(context).colorScheme.primaryContainer;
      borderColor = Theme.of(context).colorScheme.primary;
      textColor = Theme.of(context).colorScheme.onPrimaryContainer;
    } else {
      backgroundColor = Theme.of(context).colorScheme.surface;
      borderColor = isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300;
      textColor = Theme.of(context).colorScheme.onSurface;
    }

    final badgeColor =
        isSelected || showCorrect || showWrong
            ? (showCorrect
                ? (isDarkMode ? Colors.green.shade600 : Colors.green)
                : showWrong
                ? (isDarkMode ? Colors.red.shade600 : Colors.red)
                : Theme.of(context).colorScheme.primary)
            : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200);

    final badgeTextColor =
        isSelected || showCorrect || showWrong
            ? Colors.white
            : (isDarkMode ? Colors.grey.shade200 : Colors.grey.shade700);

    return GestureDetector(
      onTap: () => _selectAnswer(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  String.fromCharCode(65 + index),
                  style: TextStyle(
                    color: badgeTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                option,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (trailingIcon != null) Icon(trailingIcon, color: iconColor),
          ],
        ),
      ),
    );
  }
}
