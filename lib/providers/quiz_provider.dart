import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../services/quiz_service.dart';
import '../services/local_quiz_store.dart';
import '../services/quiz_sync_service.dart';
import '../services/connectivity_service.dart';
import '../providers/connectivity_provider.dart';
import '../models/quiz_model.dart';
import '../models/question_model.dart';

final quizServiceProvider = Provider<QuizService>((ref) => QuizService());

final localQuizStoreProvider = Provider<LocalQuizStore>(
  (_) => LocalQuizStore(),
);

final quizSyncServiceProvider = Provider<QuizSyncService>((ref) {
  return QuizSyncService(
    quizService: ref.watch(quizServiceProvider),
    localStore: ref.watch(localQuizStoreProvider),
    connectivity: ref.watch(connectivityServiceProvider),
  );
});

final userQuizzesProvider =
    StateNotifierProvider.family<QuizNotifier, AsyncValue<List<QuizModel>>, String>(
  (ref, userId) {
    final notifier = QuizNotifier(
      ref.watch(quizServiceProvider),
      ref.watch(localQuizStoreProvider),
      ref.watch(quizSyncServiceProvider),
      ref.watch(connectivityServiceProvider),
      userId,
    );

    final sub = ref.watch(connectivityServiceProvider).onlineStream.listen((
      online,
    ) {
      if (online) {
        notifier.syncPendingOperations();
      }
    });

    ref.onDispose(sub.cancel);
    return notifier;
  },
);

final currentQuizProvider = StateProvider<QuizModel?>((ref) => null);
final currentQuestionsProvider = StateProvider<List<QuestionModel>>((ref) => []);

class QuizNotifier extends StateNotifier<AsyncValue<List<QuizModel>>> {
  QuizNotifier(
    this._quizService,
    this._localStore,
    this._syncService,
    this._connectivity,
    this._userId,
  ) : super(const AsyncValue.loading()) {
    loadQuizzes();
  }

  final QuizService _quizService;
  final LocalQuizStore _localStore;
  final QuizSyncService _syncService;
  final ConnectivityService _connectivity;
  final String _userId;
  final _uuid = const Uuid();

  Future<void> loadQuizzes() async {
    final cached = await _localStore.reconcileQuestionCounts(_userId);
    if (cached.isNotEmpty) {
      state = AsyncData(cached);
    } else {
      state = const AsyncLoading<List<QuizModel>>().copyWithPrevious(state);
    }

    try {
      await syncPendingOperations();
      final quizzes = await _quizService.getUserQuizzes(_userId);
      final merged = await _mergeRemoteWithLocal(quizzes);
      await _localStore.saveQuizzes(_userId, merged);
      state = AsyncData(merged);

      // Download every quiz's questions in the background so ALL quizzes
      // (not just the ones the user happened to open) are fully available
      // for viewing and studying later, even with zero internet connection.
      unawaited(_prefetchAllQuestions(merged));
    } catch (_) {
      final local = await _localStore.reconcileQuestionCounts(_userId);
      state = AsyncData(local);
    }
  }

  /// Ensures every quiz's questions are cached locally so quiz detail,
  /// flashcards, and quiz-mode study all work fully offline — even for
  /// quizzes the user never manually opened while online.
  Future<void> _prefetchAllQuestions(List<QuizModel> quizzes) async {
    if (!await _connectivity.isOnline) return;

    for (final quiz in quizzes) {
      try {
        final cachedQuestions = await _localStore.loadQuestions(quiz.id);
        // Skip quizzes that are already fully cached — avoids re-downloading
        // everything on every single app open.
        if (quiz.questionIds.isNotEmpty &&
            cachedQuestions.length == quiz.questionIds.length) {
          continue;
        }

        final result = await _quizService.getQuizWithQuestions(quiz.id);
        if (result.$2.isNotEmpty) {
          await _localStore.saveQuestions(quiz.id, result.$2);
        }
      } catch (_) {
        // Best-effort — keep going so one bad quiz doesn't block the rest.
      }
    }

    // Refresh state so freshly cached quizzes reflect reconciled counts.
    await _emitLocalQuizzes();
  }

  Future<List<QuizModel>> _mergeRemoteWithLocal(List<QuizModel> remote) async {
    final local = await _localStore.loadQuizzes(_userId);
    final pending = await _localStore.loadPendingOperations(_userId);
    final pendingQuizIds = pending
        .where((op) => op.type == 'createQuiz')
        .map((op) => op.payload['id'] as String)
        .toSet();

    final remoteIds = remote.map((q) => q.id).toSet();
    final localOnly = local.where(
      (quiz) => !remoteIds.contains(quiz.id) && pendingQuizIds.contains(quiz.id),
    );

    final merged = [...localOnly, ...remote];
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  Future<void> syncPendingOperations() async {
    await _syncService.syncPendingOperations(_userId);
    final local = await _localStore.reconcileQuestionCounts(_userId);
    if (local.isNotEmpty) {
      state = AsyncData(local);
    }
  }

  Future<void> _emitLocalQuizzes() async {
    final quizzes = await _localStore.reconcileQuestionCounts(_userId);
    state = AsyncData(quizzes);
  }

  Future<QuizModel> createQuiz({
    required String title,
    String? description,
    String? category,
  }) async {
    final quiz = QuizModel(
      id: _uuid.v4(),
      userId: _userId,
      title: title,
      description: description,
      questionIds: [],
      createdAt: DateTime.now(),
      lastModifiedAt: DateTime.now(),
      category: category,
    );

    await _localStore.upsertQuiz(_userId, quiz);
    await _syncService.queueOrSync(
      userId: _userId,
      type: 'createQuiz',
      payload: quiz.toFirestore(),
    );
    await _emitLocalQuizzes();
    return quiz;
  }

  Future<void> saveGeneratedQuiz(
    QuizModel quiz,
    List<QuestionModel> questions,
  ) async {
    await _localStore.upsertQuiz(_userId, quiz);
    await _localStore.saveQuestions(quiz.id, questions);
    for (final question in questions) {
      await _localStore.appendQuestionIdToQuiz(_userId, quiz.id, question.id);
    }

    if (await _connectivity.isOnline) {
      try {
        await _quizService.saveGeneratedQuiz(quiz, questions);
        await loadQuizzes();
        return;
      } catch (_) {
        // Queue below if Firestore is unreachable.
      }
    }

    await _syncService.queueOrSync(
      userId: _userId,
      type: 'createQuiz',
      payload: quiz.toFirestore(),
    );
    for (final question in questions) {
      await _syncService.queueOrSync(
        userId: _userId,
        type: 'addQuestion',
        payload: question.toFirestore(),
      );
    }
    await _emitLocalQuizzes();
  }

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

    await _localStore.upsertQuestion(question);
    await _localStore.appendQuestionIdToQuiz(_userId, quizId, question.id);
    await _syncService.queueOrSync(
      userId: _userId,
      type: 'addQuestion',
      payload: question.toFirestore(),
    );
    await _emitLocalQuizzes();
    return question;
  }

  Future<QuizModel?> updateQuiz({
    required String quizId,
    String? title,
    String? description,
    String? category,
  }) async {
    final existing = await _localStore.findQuiz(_userId, quizId);
    if (existing == null) return null;

    final updated = existing.copyWith(
      title: title ?? existing.title,
      description: description ?? existing.description,
      category: category ?? existing.category,
      lastModifiedAt: DateTime.now(),
    );

    await _localStore.upsertQuiz(_userId, updated);
    await _syncService.queueOrSync(
      userId: _userId,
      type: 'updateQuiz',
      payload: {
        'quizId': quizId,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (category != null) 'category': category,
      },
    );
    await _emitLocalQuizzes();
    return updated;
  }

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
    QuestionModel? existing;
    final quizzes = await _localStore.loadQuizzes(_userId);
    for (final quiz in quizzes) {
      final questions = await _localStore.loadQuestions(quiz.id);
      for (final question in questions) {
        if (question.id == questionId) {
          existing = question;
          break;
        }
      }
      if (existing != null) break;
    }
    if (existing == null) return null;

    final updated = existing.copyWith(
      questionText: questionText ?? existing.questionText,
      options: options ?? existing.options,
      correctAnswerIndex: correctAnswerIndex ?? existing.correctAnswerIndex,
      isFlashcard: isFlashcard ?? existing.isFlashcard,
      flashcardBack: flashcardBack ?? existing.flashcardBack,
      questionType: questionType ?? existing.questionType,
      imageUrl: imageUrl ?? existing.imageUrl,
    );

    await _localStore.upsertQuestion(updated);
    await _syncService.queueOrSync(
      userId: _userId,
      type: 'updateQuestion',
      payload: {
        'questionId': questionId,
        if (questionText != null) 'questionText': questionText,
        if (options != null) 'options': options,
        if (correctAnswerIndex != null) 'correctAnswerIndex': correctAnswerIndex,
        if (isFlashcard != null) 'isFlashcard': isFlashcard,
        if (flashcardBack != null) 'flashcardBack': flashcardBack,
        if (questionType != null) 'questionType': questionType,
        if (imageUrl != null) 'imageUrl': imageUrl,
      },
    );
    await _emitLocalQuizzes();
    return updated;
  }

  Future<void> deleteQuestion(String questionId) async {
    final quizzes = await _localStore.loadQuizzes(_userId);
    for (final quiz in quizzes) {
      final questions = await _localStore.loadQuestions(quiz.id);
      if (questions.any((q) => q.id == questionId)) {
        await _localStore.removeQuestion(quiz.id, questionId);
        await _localStore.removeQuestionIdFromQuiz(_userId, quiz.id, questionId);
        await _syncService.queueOrSync(
          userId: _userId,
          type: 'deleteQuestion',
          payload: {'questionId': questionId},
        );
        break;
      }
    }
    await _emitLocalQuizzes();
  }

  Future<void> deleteQuiz(String quizId) async {
    await _localStore.removeQuiz(_userId, quizId);
    await _syncService.queueOrSync(
      userId: _userId,
      type: 'deleteQuiz',
      payload: {'quizId': quizId},
    );
    await _emitLocalQuizzes();
  }

  Future<(QuizModel?, List<QuestionModel>)> getQuizWithQuestions(
    String quizId,
  ) async {
    final cachedQuestions = await _localStore.loadQuestions(quizId);
    final cachedQuiz = await _localStore.findQuiz(_userId, quizId);

    if (cachedQuestions.isNotEmpty && cachedQuiz != null) {
      _refreshQuizWithQuestionsInBackground(quizId);
      return (cachedQuiz, cachedQuestions);
    }

    try {
      final result = await _quizService.getQuizWithQuestions(quizId);
      if (result.$1 != null) {
        await _localStore.upsertQuiz(_userId, result.$1!);
      }
      if (result.$2.isNotEmpty) {
        await _localStore.saveQuestions(quizId, result.$2);
        if (result.$1 != null) {
          await _localStore.upsertQuiz(
            _userId,
            result.$1!.copyWith(
              questionIds: result.$2.map((q) => q.id).toList(),
            ),
          );
        }
      }
      return result;
    } catch (_) {
      return (cachedQuiz, cachedQuestions);
    }
  }

  Future<void> _refreshQuizWithQuestionsInBackground(String quizId) async {
    if (!await _connectivity.isOnline) return;

    try {
      final result = await _quizService.getQuizWithQuestions(quizId);
      if (result.$1 != null) {
        await _localStore.upsertQuiz(_userId, result.$1!);
      }
      if (result.$2.isNotEmpty) {
        await _localStore.saveQuestions(quizId, result.$2);
      }
      await _emitLocalQuizzes();
    } catch (_) {
      // Keep serving cached content.
    }
  }

  Future<void> refreshQuizzes() async => loadQuizzes();

  Future<void> updateQuizStats(
    String quizId,
    int score,
    int totalQuestions,
  ) async {
    final quiz = await _localStore.findQuiz(_userId, quizId);
    if (quiz != null) {
      final newStudyCount = (quiz.studyCount ?? 0) + 1;
      final scorePercentage =
          totalQuestions > 0 ? score / totalQuestions : 0.0;
      final newAverageScore =
          ((quiz.averageScore ?? 0) * (newStudyCount - 1) + scorePercentage) /
          newStudyCount;

      await _localStore.upsertQuiz(
        _userId,
        quiz.copyWith(
          studyCount: newStudyCount,
          averageScore: newAverageScore,
          lastModifiedAt: DateTime.now(),
        ),
      );
      await _emitLocalQuizzes();
    }

    await _syncService.queueOrSync(
      userId: _userId,
      type: 'updateStats',
      payload: {
        'quizId': quizId,
        'score': score,
        'totalQuestions': totalQuestions,
      },
    );
  }

  Future<List<QuizModel>> searchQuizzes(String query) async {
    try {
      return await _quizService.searchQuizzes(query, _userId);
    } catch (_) {
      final quizzes = await _localStore.loadQuizzes(_userId);
      if (query.isEmpty) return quizzes;

      final lowerQuery = query.toLowerCase();
      return quizzes.where((quiz) {
        return quiz.title.toLowerCase().contains(lowerQuery) ||
            (quiz.description?.toLowerCase().contains(lowerQuery) ?? false) ||
            (quiz.category?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();
    }
  }
}

final searchQueryProvider = StateProvider<String>((ref) => '');

final filteredQuizzesProvider =
    Provider.family<AsyncValue<List<QuizModel>>, String>((ref, userId) {
  final query = ref.watch(searchQueryProvider);
  final quizzesAsync = ref.watch(userQuizzesProvider(userId));

  return quizzesAsync.whenData((quizzes) {
    if (query.isEmpty) return quizzes;
    final lowerQuery = query.toLowerCase();
    return quizzes.where((quiz) {
      return quiz.title.toLowerCase().contains(lowerQuery) ||
          (quiz.description?.toLowerCase().contains(lowerQuery) ?? false) ||
          (quiz.category?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  });
});