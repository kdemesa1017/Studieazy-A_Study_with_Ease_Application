import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/quiz_model.dart';
import '../models/question_model.dart';

class QuizService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  static const Duration _networkTimeout = Duration(seconds: 12);

  // Create a new quiz
  Future<QuizModel> createQuiz({
    required String userId,
    required String title,
    String? description,
    String? category,
  }) async {
    final quiz = QuizModel(
      id: _uuid.v4(),
      userId: userId,
      title: title,
      description: description,
      questionIds: [],
      createdAt: DateTime.now(),
      lastModifiedAt: DateTime.now(),
      category: category,
    );

    await _firestore.collection('quizzes').doc(quiz.id).set(quiz.toFirestore());
    return quiz;
  }

  /// Saves a quiz that was already created locally (preserves the local ID).
  Future<void> saveQuiz(QuizModel quiz) async {
    await _firestore.collection('quizzes').doc(quiz.id).set(quiz.toFirestore());
  }

  /// Saves a question that was already created locally and updates quiz metadata.
  Future<void> saveQuestion(QuestionModel question) async {
    await _firestore
        .collection('questions')
        .doc(question.id)
        .set(question.toFirestore());

    final quizDoc = await _firestore.collection('quizzes').doc(question.quizId).get();
    if (quizDoc.exists && quizDoc.data() != null) {
      final quiz = QuizModel.fromFirestore(quizDoc.data()!);
      if (!quiz.questionIds.contains(question.id)) {
        final updatedQuestionIds = [...quiz.questionIds, question.id];
        await _firestore.collection('quizzes').doc(question.quizId).update({
          'questionIds': updatedQuestionIds,
          'lastModifiedAt': DateTime.now().toIso8601String(),
        });
      }
    } else {
      // Quiz may still be syncing — create a minimal quiz doc if needed.
      await _firestore.collection('quizzes').doc(question.quizId).set({
        'id': question.quizId,
        'questionIds': [question.id],
        'lastModifiedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    }
  }

  /// Saves an AI-generated quiz and all its questions in a single batch write.
  Future<void> saveGeneratedQuiz(
    QuizModel quiz,
    List<QuestionModel> questions,
  ) async {
    final batch = _firestore.batch();
    batch.set(_firestore.collection('quizzes').doc(quiz.id), quiz.toFirestore());
    for (final q in questions) {
      batch.set(_firestore.collection('questions').doc(q.id), q.toFirestore());
    }
    await batch.commit();
  }

  // Add question to quiz
  Future<QuestionModel> addQuestion({
    required String quizId,
    required String questionText,
    required List<String> options,
    required int correctAnswerIndex,
    bool isFlashcard = false,
    String? flashcardBack,
    String questionType = 'mcq',
    String? imageUrl,
  }) async {
    final question = QuestionModel(
      id: _uuid.v4(),
      quizId: quizId,
      questionText: questionText,
      options: options,
      correctAnswerIndex: correctAnswerIndex,
      isFlashcard: isFlashcard,
      flashcardBack: flashcardBack,
      questionType: questionType,
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('questions').doc(question.id).set(question.toFirestore());

    final quizDoc = await _firestore.collection('quizzes').doc(quizId).get();
    if (quizDoc.exists && quizDoc.data() != null) {
      final quiz = QuizModel.fromFirestore(quizDoc.data()!);
      final updatedQuestionIds = [...quiz.questionIds, question.id];
      final updatedQuiz = quiz.copyWith(
        questionIds: updatedQuestionIds,
        lastModifiedAt: DateTime.now(),
      );
      await _firestore.collection('quizzes').doc(quizId).update({
        'questionIds': updatedQuestionIds,
        'lastModifiedAt': updatedQuiz.lastModifiedAt!.toIso8601String(),
      });
    }

    return question;
  }

  // Update quiz
  Future<QuizModel?> updateQuiz({
    required String quizId,
    String? title,
    String? description,
    String? category,
  }) async {
    final doc = await _firestore.collection('quizzes').doc(quizId).get();
    if (!doc.exists || doc.data() == null) return null;

    final quiz = QuizModel.fromFirestore(doc.data()!);
    final updatedQuiz = quiz.copyWith(
      title: title ?? quiz.title,
      description: description ?? quiz.description,
      category: category ?? quiz.category,
      lastModifiedAt: DateTime.now(),
    );

    await _firestore.collection('quizzes').doc(quizId).update({
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (category != null) 'category': category,
      'lastModifiedAt': updatedQuiz.lastModifiedAt!.toIso8601String(),
    });

    return updatedQuiz;
  }

  // Update question
  Future<QuestionModel?> updateQuestion({
    required String questionId,
    String? questionText,
    List<String>? options,
    int? correctAnswerIndex,
    bool? isFlashcard,
    String? flashcardBack,
    String? questionType,
    String? imageUrl,
  }) async {
    final doc = await _firestore.collection('questions').doc(questionId).get();
    if (!doc.exists || doc.data() == null) return null;

    final question = QuestionModel.fromFirestore(doc.data()!);
    final updatedQuestion = question.copyWith(
      questionText: questionText ?? question.questionText,
      options: options ?? question.options,
      correctAnswerIndex: correctAnswerIndex ?? question.correctAnswerIndex,
      isFlashcard: isFlashcard ?? question.isFlashcard,
      flashcardBack: flashcardBack ?? question.flashcardBack,
      questionType: questionType ?? question.questionType,
      imageUrl: imageUrl ?? question.imageUrl,
    );

    await _firestore.collection('questions').doc(questionId).update(updatedQuestion.toFirestore());

    await _firestore.collection('quizzes').doc(question.quizId).update({
      'lastModifiedAt': DateTime.now().toIso8601String(),
    });

    return updatedQuestion;
  }

  // Delete question
  Future<void> deleteQuestion(String questionId) async {
    final doc = await _firestore.collection('questions').doc(questionId).get();
    if (!doc.exists || doc.data() == null) return;

    final question = QuestionModel.fromFirestore(doc.data()!);
    await _firestore.collection('questions').doc(questionId).delete();

    final quizDoc = await _firestore.collection('quizzes').doc(question.quizId).get();
    if (quizDoc.exists && quizDoc.data() != null) {
      final quiz = QuizModel.fromFirestore(quizDoc.data()!);
      final updatedQuestionIds = quiz.questionIds.where((id) => id != questionId).toList();
      await _firestore.collection('quizzes').doc(question.quizId).update({
        'questionIds': updatedQuestionIds,
        'lastModifiedAt': DateTime.now().toIso8601String(),
      });
    }
  }

  // Delete quiz
  Future<void> deleteQuiz(String quizId) async {
    final questionsSnapshot = await _firestore
        .collection('questions')
        .where('quizId', isEqualTo: quizId)
        .get();

    for (final doc in questionsSnapshot.docs) {
      await doc.reference.delete();
    }

    await _firestore.collection('quizzes').doc(quizId).delete();
  }

  // Get user's quizzes from Firestore
  Future<List<QuizModel>> getUserQuizzes(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('quizzes')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(200)
          .get()
          .timeout(
            _networkTimeout,
            onTimeout: () => throw 'Request timed out. Please check your connection and try again.',
          );

      return snapshot.docs
          .map((doc) => QuizModel.fromFirestore(doc.data()))
          .toList();
    } on FirebaseException catch (e) {
      // If index is missing, fall back to a non-ordered query so the app still works.
      if (e.code == 'failed-precondition') {
        final snapshot = await _firestore
            .collection('quizzes')
            .where('userId', isEqualTo: userId)
            .limit(200)
            .get()
            .timeout(
              _networkTimeout,
              onTimeout: () => throw 'Request timed out. Please check your connection and try again.',
            );

        final quizzes = snapshot.docs
            .map((doc) => QuizModel.fromFirestore(doc.data()))
            .toList();
        quizzes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return quizzes;
      }
      rethrow;
    }
  }

  // Get quiz with questions from Firestore
  Future<(QuizModel?, List<QuestionModel>)> getQuizWithQuestions(String quizId) async {
    final quizDoc = await _firestore
        .collection('quizzes')
        .doc(quizId)
        .get()
        .timeout(
          _networkTimeout,
          onTimeout: () => throw 'Request timed out. Please check your connection and try again.',
        );
    if (!quizDoc.exists || quizDoc.data() == null) return (null, <QuestionModel>[]);

    final quiz = QuizModel.fromFirestore(quizDoc.data()!);

    final questionsSnapshot = await _firestore
        .collection('questions')
        .where('quizId', isEqualTo: quizId)
        .get()
        .timeout(
          _networkTimeout,
          onTimeout: () => throw 'Request timed out. Please check your connection and try again.',
        );

    final questions = questionsSnapshot.docs
        .map<QuestionModel>((doc) => QuestionModel.fromFirestore(doc.data()))
        .toList();

    return (quiz, questions);
  }

  // Refresh quizzes from Firestore
  Future<List<QuizModel>> refreshQuizzes(String userId) async {
    return getUserQuizzes(userId);
  }

  // Update quiz statistics after study session
  Future<void> updateQuizStats(String quizId, int score, int totalQuestions) async {
    final doc = await _firestore.collection('quizzes').doc(quizId).get();
    if (!doc.exists || doc.data() == null) return;

    final quiz = QuizModel.fromFirestore(doc.data()!);
    final newStudyCount = (quiz.studyCount ?? 0) + 1;
    final scorePercentage = totalQuestions > 0 ? score / totalQuestions : 0.0;
    final newAverageScore = ((quiz.averageScore ?? 0) * (newStudyCount - 1) + scorePercentage) / newStudyCount;

    await _firestore.collection('quizzes').doc(quizId).update({
      'studyCount': newStudyCount,
      'averageScore': newAverageScore,
      'lastModifiedAt': DateTime.now().toIso8601String(),
    });
  }

  // Search quizzes
  Future<List<QuizModel>> searchQuizzes(String query, String userId) async {
    final quizzes = await getUserQuizzes(userId);
    if (query.isEmpty) return quizzes;

    final lowerQuery = query.toLowerCase();
    return quizzes.where((quiz) {
      return quiz.title.toLowerCase().contains(lowerQuery) ||
          (quiz.description?.toLowerCase().contains(lowerQuery) ?? false) ||
          (quiz.category?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }
}
