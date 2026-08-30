import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/quiz/create_quiz_screen.dart';
import 'screens/quiz/my_quizzes_screen.dart';
import 'screens/quiz/quiz_detail_screen.dart';
import 'screens/study/study_mode_screen.dart';
import 'screens/study/flashcard_study_screen.dart';
import 'screens/study/quiz_study_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/main_layout.dart';
import 'screens/ai_quiz/ai_quiz_generator_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<dynamic>>(
      currentUserProvider,
      (previous, next) {
        final prevUser = previous?.valueOrNull;
        final nextUser = next.valueOrNull;
        final prevIsLoggedIn = prevUser != null;
        final nextIsLoggedIn = nextUser != null;

        if (prevIsLoggedIn != nextIsLoggedIn || previous?.isLoading != next.isLoading) {
          notifyListeners();
        }
      },
    );
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      // While auth is still initialising, don't redirect at all.
      // Cached session may already be loaded; avoid a flash to /login.
      final currentUserAsync = ref.read(currentUserProvider);
      if (currentUserAsync.isLoading) return null;

      final isLoggedIn = currentUserAsync.valueOrNull != null;
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }

      if (isLoggedIn && isAuthRoute) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainLayout(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/create-quiz',
            builder: (context, state) => const CreateQuizScreen(),
          ),
          GoRoute(
            path: '/my-quizzes',
            builder: (context, state) => const MyQuizzesScreen(),
          ),
          GoRoute(
            path: '/quiz/:id',
            builder: (context, state) {
              final quizId = state.pathParameters['id']!;
              return QuizDetailScreen(quizId: quizId);
            },
          ),
          GoRoute(
            path: '/study',
            builder: (context, state) => const StudyModeScreen(),
          ),
          GoRoute(
            path: '/study/flashcard/:id',
            builder: (context, state) {
              final quizId = state.pathParameters['id']!;
              return FlashcardStudyScreen(quizId: quizId);
            },
          ),
          GoRoute(
            path: '/study/quiz/:id',
            builder: (context, state) {
              final quizId = state.pathParameters['id']!;
              return QuizStudyScreen(quizId: quizId);
            },
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/ai-generator',
            builder: (context, state) => const AiQuizGeneratorScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
    ],
  );
});

class StudieazyApp extends ConsumerWidget {
  const StudieazyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Studieazy',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Inter',
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(color: Color(0xFF374151)),
          hintStyle: const TextStyle(color: Color(0xFF6B7280)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Inter',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1F2937),
          labelStyle: const TextStyle(color: Color(0xFFE5E7EB)),
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF4B5563)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFA5B4FC), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}
