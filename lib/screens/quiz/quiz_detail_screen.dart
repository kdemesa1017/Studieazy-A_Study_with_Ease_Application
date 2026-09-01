import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/quiz_provider.dart';
import '../../models/quiz_model.dart';
import '../../models/question_model.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/app_question_image.dart';

class QuizDetailScreen extends ConsumerStatefulWidget {
  final String quizId;

  const QuizDetailScreen({super.key, required this.quizId});

  @override
  ConsumerState<QuizDetailScreen> createState() => _QuizDetailScreenState();
}

class _EditQuizBottomSheet extends ConsumerStatefulWidget {
  final QuizModel quiz;
  final VoidCallback onSaved;

  const _EditQuizBottomSheet({required this.quiz, required this.onSaved});

  @override
  ConsumerState<_EditQuizBottomSheet> createState() =>
      _EditQuizBottomSheetState();
}

class _EditQuizBottomSheetState extends ConsumerState<_EditQuizBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.quiz.title);
    _descriptionController = TextEditingController(
      text: widget.quiz.description ?? '',
    );
    _categoryController = TextEditingController(
      text: widget.quiz.category ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      setState(() => _isSaving = false);
      return;
    }

    await ref
        .read(userQuizzesProvider(user.id).notifier)
        .updateQuiz(
          quizId: widget.quiz.id,
          title: _titleController.text.trim(),
          description:
              _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
          category:
              _categoryController.text.trim().isEmpty
                  ? null
                  : _categoryController.text.trim(),
        );

    if (!mounted) return;
    Navigator.pop(context);
    await Future.delayed(const Duration(milliseconds: 250));
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit Quiz',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Quiz Title *'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a quiz title';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child:
                    _isSaving
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditQuestionBottomSheet extends ConsumerStatefulWidget {
  final QuestionModel question;
  final VoidCallback onSaved;

  const _EditQuestionBottomSheet({
    required this.question,
    required this.onSaved,
  });

  @override
  ConsumerState<_EditQuestionBottomSheet> createState() =>
      _EditQuestionBottomSheetState();
}

class _EditQuestionBottomSheetState
    extends ConsumerState<_EditQuestionBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _questionController;
  late final TextEditingController _backController;
  late final List<TextEditingController> _optionControllers;
  // For enumeration — dynamic list of items
  late final List<TextEditingController> _enumControllers;

  late String _questionType; // 'mcq', 'flashcard', 'identification', 'enumeration'
  int _correctAnswerIndex = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _questionType = widget.question.questionType;
    _correctAnswerIndex = widget.question.correctAnswerIndex;

    _questionController = TextEditingController(
      text: widget.question.questionText,
    );
    _backController = TextEditingController(
      text: widget.question.flashcardBack ?? '',
    );

    final initialOptions = widget.question.options;
    _optionControllers = List.generate(
      4,
      (i) => TextEditingController(
        text: i < initialOptions.length ? initialOptions[i] : '',
      ),
    );

    // Pre-fill enum controllers from existing options when editing an enumeration
    if (_questionType == 'enumeration') {
      _enumControllers = List.generate(
        initialOptions.isNotEmpty ? initialOptions.length : 3,
        (i) => TextEditingController(
          text: i < initialOptions.length ? initialOptions[i] : '',
        ),
      );
    } else {
      _enumControllers = List.generate(3, (_) => TextEditingController());
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _backController.dispose();
    for (final c in _optionControllers) { c.dispose(); }
    for (final c in _enumControllers) { c.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      setState(() => _isSaving = false);
      return;
    }

    List<String> options;
    String? flashcardBack;
    bool isFlashcard = _questionType == 'flashcard';

    switch (_questionType) {
      case 'flashcard':
        options = [_backController.text.trim()];
        flashcardBack = _backController.text.trim();
        break;
      case 'identification':
        options = [_backController.text.trim()];
        flashcardBack = _backController.text.trim();
        break;
      case 'enumeration':
        options = _enumControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList();
        flashcardBack = options.join(', ');
        break;
      default: // mcq
        options = _optionControllers.map((c) => c.text.trim()).toList();
        flashcardBack = null;
    }

    await ref
        .read(userQuizzesProvider(user.id).notifier)
        .updateQuestion(
          questionId: widget.question.id,
          questionText: _questionController.text.trim(),
          options: options,
          correctAnswerIndex: _questionType == 'mcq' ? _correctAnswerIndex : 0,
          isFlashcard: isFlashcard,
          flashcardBack: flashcardBack,
          questionType: _questionType,
        );

    if (!mounted) return;
    Navigator.pop(context);
    await Future.delayed(const Duration(milliseconds: 250));
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit Question',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Type Selector
              _buildTypePicker(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _questionController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Question *'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a question';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _buildAnswerFields(),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypePicker() {
    const types = [
      ('mcq', 'MCQ', Icons.list_alt_rounded),
      ('flashcard', 'Flashcard', Icons.flip_rounded),
      ('identification', 'Identification', Icons.edit_note_rounded),
      ('enumeration', 'Enumeration', Icons.format_list_numbered_rounded),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: types.map((t) {
          final isSelected = _questionType == t.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(t.$3, size: 16),
              label: Text(t.$2),
              selected: isSelected,
              onSelected: (_) => setState(() {
                _questionType = t.$1;
                _correctAnswerIndex = 0;
              }),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAnswerFields() {
    switch (_questionType) {
      case 'flashcard':
        return TextFormField(
          controller: _backController,
          decoration: const InputDecoration(labelText: 'Answer (Back of card) *'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter the answer' : null,
        );
      case 'identification':
        return TextFormField(
          controller: _backController,
          decoration: const InputDecoration(
            labelText: 'Answer (short keyword) *',
            hintText: 'e.g., Phishing',
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter the answer' : null,
        );
      case 'enumeration':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Answer Items',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            ...List.generate(_enumControllers.length, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _enumControllers[i],
                      decoration: InputDecoration(labelText: 'Item ${i + 1} *'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter item' : null,
                    ),
                  ),
                  if (_enumControllers.length > 1)
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: () => setState(() {
                        _enumControllers.removeAt(i);
                      }),
                    ),
                ],
              ),
            )),
            TextButton.icon(
              onPressed: () => setState(() {
                _enumControllers.add(TextEditingController());
              }),
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            ),
          ],
        );
      default: // mcq
        return RadioGroup<int>(
          groupValue: _correctAnswerIndex,
          onChanged: (value) {
            if (value != null) setState(() => _correctAnswerIndex = value);
          },
          child: Column(
            children: [
              ..._optionControllers.asMap().entries.map((entry) {
                final index = entry.key;
                final controller = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Radio<int>(value: index),
                      Expanded(
                        child: TextFormField(
                          controller: controller,
                          decoration: InputDecoration(labelText: 'Option ${index + 1} *'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter this option';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
    }
  }
}

class _QuizDetailScreenState extends ConsumerState<QuizDetailScreen> {
  bool _isLoading = true;
  QuizModel? _quiz;
  List<QuestionModel> _questions = [];

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  void _showResultModal(String title, String message, bool isSuccess) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      isSuccess
                          ? [Colors.green.shade50, Colors.white]
                          : [Colors.red.shade50, Colors.white],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors:
                            isSuccess
                                ? [Colors.green, Colors.green.shade600]
                                : [Colors.red, Colors.red.shade600],
                      ),
                    ),
                    child: Icon(
                      isSuccess
                          ? Icons.check_rounded
                          : Icons.priority_high_rounded,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color:
                          isSuccess
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSuccess ? Colors.green : Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'OK',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _editQuiz() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null || _quiz == null) return;
    if (_quiz!.userId != user.id) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => _EditQuizBottomSheet(
            quiz: _quiz!,
            onSaved: () {
              _loadQuiz();
              _showResultModal(
                'Quiz Updated!',
                'Quiz details have been updated successfully.',
                true,
              );
            },
          ),
    );
  }

  Future<void> _editQuestion(QuestionModel question) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null || _quiz == null) return;
    if (_quiz!.userId != user.id) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => _EditQuestionBottomSheet(
            question: question,
            onSaved: () {
              _loadQuiz();
              _showResultModal(
                'Question Saved!',
                'Question details updated successfully.',
                true,
              );
            },
          ),
    );
  }

  Future<void> _loadQuiz() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;

    final (quiz, questions) = await ref
        .read(userQuizzesProvider(user.id).notifier)
        .getQuizWithQuestions(widget.quizId);

    if (mounted) {
      setState(() {
        _quiz = quiz;
        _questions = questions;
        _isLoading = false;
      });
      // If quiz was deleted, navigate away
      if (quiz == null) {
        context.go('/my-quizzes');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This quiz no longer exists')),
        );
      }
    }
  }

  Future<void> _deleteQuestion(String questionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Question'),
            content: const Text(
              'Are you sure you want to delete this question?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user != null) {
        await ref
            .read(userQuizzesProvider(user.id).notifier)
            .deleteQuestion(questionId);
        _loadQuiz();
      }
    }
  }

  Future<void> _deleteQuiz() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Quiz'),
            content: Text('Are you sure you want to delete "${_quiz?.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user != null) {
        await ref
            .read(userQuizzesProvider(user.id).notifier)
            .deleteQuiz(widget.quizId);
        if (mounted) {
          context.go('/my-quizzes');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quiz deleted successfully')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        resizeToAvoidBottomInset: false,
        body: PageSkeleton(list: true),
      );
    }

    if (_quiz == null) {
      return const Scaffold(
        resizeToAvoidBottomInset: false,
        body: PageSkeleton(list: true),
      );
    }

    final theme = Theme.of(context);
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    final canEdit = currentUser != null && _quiz!.userId == currentUser.id;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _quiz!.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Decorative image (no assets needed)
                  Image.network(
                    'https://images.unsplash.com/photo-1523240795612-9a054b0db644?auto=format&fit=crop&w=1200&q=60',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.secondary,
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  // Scrim so text stays readable
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.25),
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                  // Existing content
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_quiz!.category != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _quiz!.category!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        if (_quiz!.description != null)
                          Text(
                            _quiz!.description!,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _editQuiz();
                      break;
                    case 'delete':
                      _deleteQuiz();
                      break;
                  }
                },
                itemBuilder:
                    (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        enabled: canEdit,
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              color: canEdit ? null : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Edit Quiz',
                              style: TextStyle(
                                color: canEdit ? null : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              'Delete Quiz',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
              ),
            ],
          ),

          // Stats
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildStatCard(
                    context,
                    icon: Icons.help_outline,
                    value: '${_questions.length}',
                    label: 'Questions',
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    context,
                    icon: Icons.school_outlined,
                    value: '${_quiz!.studyCount ?? 0}',
                    label: 'Study Sessions',
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    context,
                    icon: Icons.trending_up,
                    value: '${((_quiz!.averageScore ?? 0) * 100).toInt()}%',
                    label: 'Avg Score',
                  ),
                ],
              ),
            ),
          ),

          // Study Buttons
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _StudyActionButton(
                      label: 'Flashcards',
                      subtitle: 'Review and memorize key concepts',
                      icon: Icons.style_rounded,
                      gradientColors: const [Color(0xFFFF8C00), Color(0xFFFF6B00)],
                      shadowColor: Colors.orange,
                      onPressed: _questions.isEmpty
                          ? null
                          : () => context.push('/study/flashcard/${widget.quizId}'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StudyActionButton(
                      label: 'Quiz Mode',
                      subtitle: 'Test your knowledge with practice questions',
                      icon: Icons.quiz_rounded,
                      gradientColors: const [Color(0xFF22C55E), Color(0xFF16A34A)],
                      shadowColor: Colors.green,
                      onPressed: _questions.isEmpty
                          ? null
                          : () => context.push('/study/quiz/${widget.quizId}'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Questions Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Questions',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  MouseRegion(
                    cursor: canEdit ? SystemMouseCursors.click : SystemMouseCursors.basic,
                    child: TextButton.icon(
                      onPressed: canEdit ? () => _showAddQuestionDialog() : null,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Question'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Questions List
          if (_questions.isEmpty)
            SliverToBoxAdapter(child: _buildEmptyQuestionsState(context))
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final question = _questions[index];
                return _buildQuestionTile(context, question);
              }, childCount: _questions.length),
            ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionTile(BuildContext context, QuestionModel question) {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    final canEdit =
        currentUser != null && _quiz != null && _quiz!.userId == currentUser.id;

    return MouseRegion(
      cursor: canEdit ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: ListTile(
          onTap: canEdit ? () => _editQuestion(question) : null,
          title: Text(
            question.questionText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              Text(
                question.isEnumeration
                    ? '${question.options.length} items to enumerate'
                    : question.isIdentification
                        ? 'Identification'
                        : question.isFlashcard
                            ? 'Flashcard'
                            : '${question.options.length} options',
              ),
              if (question.imageUrl != null && question.imageUrl!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_outlined, size: 12, color: Color(0xFF6366F1)),
                      SizedBox(width: 3),
                      Text(
                        'Image',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: question.isEnumeration
                  ? Colors.orange.withValues(alpha: 0.2)
                  : question.isIdentification
                      ? Colors.teal.withValues(alpha: 0.2)
                      : question.isFlashcard
                          ? Colors.purple.withValues(alpha: 0.2)
                          : Colors.blue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              question.isEnumeration
                  ? Icons.format_list_numbered_rounded
                  : question.isIdentification
                      ? Icons.edit_note_rounded
                      : question.isFlashcard
                          ? Icons.flip
                          : Icons.help_outline,
              size: 20,
              color: question.isEnumeration
                  ? Colors.orange
                  : question.isIdentification
                      ? Colors.teal
                      : question.isFlashcard
                          ? Colors.purple
                          : Colors.blue,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (question.imageUrl != null && question.imageUrl!.isNotEmpty)
                AppQuestionImage(
                  imageUrl: question.imageUrl,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(6),
                ),
              if (canEdit)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteQuestion(question.id),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyQuestionsState(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.help_outline, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No questions yet',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showAddQuestionDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add Question'),
          ),
        ],
      ),
    );
  }

  void _showAddQuestionDialog() {
    // Navigate to create quiz screen for now
    // In a full implementation, this would show a dialog to add a single question
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => _AddQuestionBottomSheet(
            quizId: widget.quizId,
            onQuestionAdded: _loadQuiz,
          ),
    );
  }
}

class _AddQuestionBottomSheet extends ConsumerStatefulWidget {
  final String quizId;
  final VoidCallback onQuestionAdded;

  const _AddQuestionBottomSheet({
    required this.quizId,
    required this.onQuestionAdded,
  });

  @override
  ConsumerState<_AddQuestionBottomSheet> createState() =>
      _AddQuestionBottomSheetState();
}

class _AddQuestionBottomSheetState
    extends ConsumerState<_AddQuestionBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final _backController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  // For enumeration items (dynamic list)
  final List<TextEditingController> _enumControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  String _questionType = 'mcq'; // 'mcq', 'flashcard', 'identification', 'enumeration'
  int _correctAnswerIndex = 0;
  bool _isSaving = false;

  @override
  void dispose() {
    _questionController.dispose();
    _backController.dispose();
    for (var c in _optionControllers) { c.dispose(); }
    for (var c in _enumControllers) { c.dispose(); }
    super.dispose();
  }

  Future<void> _saveQuestion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final user = ref.read(currentUserProvider).valueOrNull;
    if (user != null) {
      List<String> options;
      String? flashcardBack;
      bool isFlashcard = _questionType == 'flashcard';

      switch (_questionType) {
        case 'flashcard':
          options = [_backController.text.trim()];
          flashcardBack = _backController.text.trim();
          break;
        case 'identification':
          options = [_backController.text.trim()];
          flashcardBack = _backController.text.trim();
          break;
        case 'enumeration':
          options = _enumControllers
              .map((c) => c.text.trim())
              .where((t) => t.isNotEmpty)
              .toList();
          flashcardBack = options.join(', ');
          break;
        default: // mcq
          options = _optionControllers.map((c) => c.text).toList();
          flashcardBack = null;
      }

      await ref
          .read(userQuizzesProvider(user.id).notifier)
          .addQuestion(
            quizId: widget.quizId,
            questionText: _questionController.text.trim(),
            options: options,
            correctAnswerIndex: _questionType == 'mcq' ? _correctAnswerIndex : 0,
            isFlashcard: isFlashcard,
            flashcardBack: flashcardBack,
            questionType: _questionType,
          );

      if (mounted) {
        Navigator.pop(context);
        widget.onQuestionAdded();
      }
    }

    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add Question',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Type Selector chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _typeChip('mcq', 'MCQ', Icons.list_alt_rounded),
                      const SizedBox(width: 8),
                      _typeChip('flashcard', 'Flashcard', Icons.flip_rounded),
                      const SizedBox(width: 8),
                      _typeChip('identification', 'Identification', Icons.edit_note_rounded),
                      const SizedBox(width: 8),
                      _typeChip('enumeration', 'Enumeration', Icons.format_list_numbered_rounded),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _questionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Question',
                    hintText: 'Enter your question',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a question';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildAnswerFields(),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveQuestion,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Add Question'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeChip(String type, String label, IconData icon) {
    final isSelected = _questionType == type;
    return ChoiceChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() {
        _questionType = type;
        _correctAnswerIndex = 0;
      }),
    );
  }

  Widget _buildAnswerFields() {
    switch (_questionType) {
      case 'flashcard':
        return TextFormField(
          controller: _backController,
          decoration: const InputDecoration(
            labelText: 'Answer (Back of card)',
            hintText: 'Enter the answer',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter the answer';
            return null;
          },
        );
      case 'identification':
        return TextFormField(
          controller: _backController,
          decoration: const InputDecoration(
            labelText: 'Answer (short keyword)',
            hintText: 'e.g., Phishing',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter the answer';
            return null;
          },
        );
      case 'enumeration':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Answer Items',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            ...List.generate(_enumControllers.length, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _enumControllers[i],
                      decoration: InputDecoration(labelText: 'Item ${i + 1}'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter item' : null,
                    ),
                  ),
                  if (_enumControllers.length > 1)
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: () => setState(() {
                        _enumControllers[i].dispose();
                        _enumControllers.removeAt(i);
                      }),
                    ),
                ],
              ),
            )),
            TextButton.icon(
              onPressed: () => setState(() {
                _enumControllers.add(TextEditingController());
              }),
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
            ),
          ],
        );
      default: // mcq
        return RadioGroup<int>(
          groupValue: _correctAnswerIndex,
          onChanged: (value) {
            if (value != null) setState(() => _correctAnswerIndex = value);
          },
          child: Column(
            children: [
              ..._optionControllers.asMap().entries.map((entry) {
                final index = entry.key;
                final controller = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Radio<int>(value: index),
                      Expanded(
                        child: TextFormField(
                          controller: controller,
                          decoration: InputDecoration(
                            labelText: 'Option ${index + 1}',
                            hintText: index == 0 ? 'Correct answer' : 'Wrong answer',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter this option';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
    }
  }
}

/// Gradient pill-style action button for Flashcards / Quiz Mode.
class _StudyActionButton extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final Color shadowColor;
  final VoidCallback? onPressed;

  const _StudyActionButton({
    required this.label,
    this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.shadowColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        mouseCursor: isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedOpacity(
          opacity: isDisabled ? 0.45 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: isDisabled
                  ? []
                  : [
                      BoxShadow(
                        color: shadowColor.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
