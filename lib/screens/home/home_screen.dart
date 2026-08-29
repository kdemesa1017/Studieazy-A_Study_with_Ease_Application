import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/quiz_provider.dart';
import '../../providers/streak_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../models/quiz_model.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/offline_mode_dialog.dart';
import '../../widgets/responsive_layout.dart';

// ── Design Tokens ───────────────────────────────────────────────────────────
const _kCard    = Color(0xFF1E293B);
const _kBorder  = Color(0xFF334155);
const _kOrange  = Color(0xFFFF8C00);
const _kGreen   = Color(0xFF22C55E);
const _kBlue    = Color(0xFF3B82F6);
const _kPurple  = Color(0xFF8B5CF6);
const _kIndigo  = Color(0xFF6366F1);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isOfflineMode = false;
  Timer? _slowLoadTimer;
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(streakProvider);
      _startSlowLoadTimer();
    });
  }

  @override
  void dispose() {
    _slowLoadTimer?.cancel();
    super.dispose();
  }

  void _startSlowLoadTimer() {
    _slowLoadTimer?.cancel();
    _slowLoadTimer = Timer(const Duration(seconds: 30), () {
      if (!mounted) return;
      final userAsync = ref.read(currentUserProvider);
      final user = userAsync.valueOrNull;
      final isQuizzesLoading =
          user != null && ref.read(userQuizzesProvider(user.id)).isLoading;
      final isAuthLoading = userAsync.isLoading;
      if ((isAuthLoading || isQuizzesLoading) && !_dialogShown && !_isOfflineMode) {
        _showOfflineDialog();
      }
    });
  }

  void _showOfflineDialog() {
    if (_dialogShown || !mounted) return;
    _dialogShown = true;
    OfflineModeDialog.show(
      context,
      onWait: () {
        setState(() => _dialogShown = false);
        _startSlowLoadTimer();
      },
      onGoOffline: () => setState(() => _isOfflineMode = true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    if (userAsync.isLoading && !_isOfflineMode) return const PageSkeleton();

    final user = userAsync.valueOrNull;
    final quizzesAsync = user != null
        ? ref.watch(userQuizzesProvider(user.id))
        : const AsyncValue<List<QuizModel>>.data([]);

    return quizzesAsync.when(
      data: (quizzes) => _buildContent(context, ref, user, quizzes),
      loading: () => const PageSkeleton(),
      error: (e, _) => _buildError(context, ref, user, e),
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, dynamic user, Object e) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 64, color: _kIndigo),
          const SizedBox(height: 16),
          Text('Could not load data', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Check your internet connection',
              style: TextStyle(color: Colors.grey.shade600)),
          if (user != null) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () =>
                  ref.read(userQuizzesProvider(user.id).notifier).refreshQuizzes(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _isOfflineMode = true),
              child: const Text('Use Offline Mode'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
    List<QuizModel> quizzes,
  ) {
    final recentQuizzes = quizzes.take(6).toList();
    final totalQuizzes  = quizzes.length;
    final totalQuestions = quizzes.fold<int>(0, (s, q) => s + q.questionIds.length);
    final streakAsync   = ref.watch(streakProvider);
    final streakCount   = streakAsync.valueOrNull ?? user?.streakCount ?? 0;
    final isOnline      = ref.watch(isOnlineProvider).valueOrNull ?? true;
    final isDesktop     = ResponsiveBreakpoints.isDesktop(context);

    final offlineBanner = (_isOfflineMode || !isOnline)
        ? _buildOfflineBanner(context, isOnline)
        : const SizedBox.shrink();

    Widget mainContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        offlineBanner,
        if (_isOfflineMode || !isOnline) const SizedBox(height: 12),

        // Hero Banner
        _HeroBanner(user: user),
        const SizedBox(height: 20),

        // Progress Overview
        const _SectionHeader(title: 'Your Progress Overview'),
        const SizedBox(height: 12),
        _ProgressStats(
          streakCount: streakCount,
          totalQuizzes: totalQuizzes,
          totalQuestions: totalQuestions,
        ),
        const SizedBox(height: 24),

        // Recent Study Decks + AI Promo
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionHeader(title: 'Recent Study Decks'),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => context.go('/my-quizzes'),
                child: Text(
                  '→ View All',
                  style: TextStyle(
                    color: _kIndigo,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: isDesktop ? 6 : 55,
              child: recentQuizzes.isEmpty
                  ? _EmptyDecks(onTap: () => context.go('/create-quiz'))
                  : Column(
                      children: recentQuizzes
                          .take(isDesktop ? 4 : 3)
                          .map((quiz) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _DeckListTile(quiz: quiz),
                              ))
                          .toList(),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: isDesktop ? 4 : 45,
              child: _AiPromoCard(isOnline: isOnline),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Continue Learning Journey
        const _SectionHeader(title: 'Continue Your Learning Journey'),
        const SizedBox(height: 12),
        _ContinueLearningBanner(isOnline: isOnline),
        const SizedBox(height: 24),
      ],
    );

    if (isDesktop) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: mainContent,
      );
    }

    return RefreshIndicator(
      onRefresh: user != null
          ? () => ref.read(userQuizzesProvider(user.id).notifier).refreshQuizzes()
          : () async {},
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: mainContent,
      ),
    );
  }

  Widget _buildOfflineBanner(BuildContext context, bool isOnline) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, size: 16, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline Mode — showing cached data',
              style: TextStyle(
                  color: Colors.orange.shade800,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
          if (_isOfflineMode && isOnline)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() => _isOfflineMode = false),
                child: Text(
                  'Go online',
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : const Color(0xFF1E293B),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Banner
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final dynamic user;
  const _HeroBanner({required this.user});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final showIllustration = width >= 480;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 150),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kIndigo.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          // Sparkle decorations
          Positioned(right: showIllustration ? 210 : 16, top: 12,
            child: Icon(Icons.auto_awesome, color: Colors.white.withValues(alpha: 0.15), size: 16)),
          Positioned(right: showIllustration ? 260 : 56, top: 38,
            child: Icon(Icons.star_rounded, color: Colors.white.withValues(alpha: 0.10), size: 10)),
          Positioned(right: showIllustration ? 190 : 10, bottom: 18,
            child: Icon(Icons.auto_awesome, color: Colors.white.withValues(alpha: 0.10), size: 12)),

          // Right-side decorative illustration
          if (showIllustration)
            Positioned(
              right: 0, top: 0, bottom: 0,
              child: SizedBox(
                width: 195,
                child: _HeroDecoration(),
              ),
            ),

          // Text content
          Padding(
            padding: EdgeInsets.fromLTRB(22, 26, showIllustration ? 210 : 22, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Welcome back,',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${(user?.name ?? 'Student').toUpperCase()} 👋',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'What subject would you like to master today?',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.60),
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _HeroBtn(
                      label: 'Generate with AI',
                      icon: Icons.auto_awesome_rounded,
                      onTap: () => context.go('/ai-generator'),
                      filled: true,
                    ),
                    _HeroBtn(
                      label: 'Create New Deck',
                      icon: Icons.add_rounded,
                      onTap: () => context.go('/create-quiz'),
                      filled: false,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroDecoration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Glow
        Positioned(
          right: 20, top: 15,
          child: Container(
            width: 140, height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kPurple.withValues(alpha: 0.18),
            ),
          ),
        ),
        // Person avatar
        Positioned(
          right: 52, top: 22,
          child: Container(
            width: 74, height: 74,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kIndigo, _kPurple]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: _kIndigo.withValues(alpha: 0.45), blurRadius: 18)],
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 38),
          ),
        ),
        // Floating card: Study Progress
        Positioned(
          right: 8, top: 14,
          child: _MiniFloatCard(icon: Icons.trending_up_rounded, label: 'Study Progress', color: _kIndigo),
        ),
        // Floating card: Knowledge
        Positioned(
          right: 90, bottom: 22,
          child: _MiniFloatCard(icon: Icons.pie_chart_rounded, label: 'Knowledge', color: _kOrange),
        ),
        // Floating card: Score
        Positioned(
          right: 6, bottom: 32,
          child: _MiniFloatCard(icon: Icons.star_rounded, label: 'Score', color: _kGreen),
        ),
      ],
    );
  }
}

class _MiniFloatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniFloatCard({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _HeroBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  const _HeroBtn({required this.label, required this.icon, required this.onTap, required this.filled});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: filled ? _kPurple : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: filled ? null : Border.all(color: Colors.white.withValues(alpha: 0.28)),
            boxShadow: filled
                ? [BoxShadow(color: _kPurple.withValues(alpha: 0.40), blurRadius: 10, offset: const Offset(0, 4))]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress Stats (3 cards)
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressStats extends StatelessWidget {
  final int streakCount;
  final int totalQuizzes;
  final int totalQuestions;

  const _ProgressStats({
    required this.streakCount,
    required this.totalQuizzes,
    required this.totalQuestions,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final todayLabel = '${months[now.month - 1]} ${now.day}';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        // ── Daily Streak ──
        Expanded(
          child: _StatTile(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFF6B35), _kOrange]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.local_fire_department, color: Colors.white, size: 17),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  'Daily Streak',
                  style: TextStyle(color: Colors.orange.shade400, fontSize: 10.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$streakCount',
                      style: const TextStyle(color: Color(0xFFFF8C00), fontSize: 26, fontWeight: FontWeight.bold, height: 1),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      streakCount == 1 ? 'day' : 'days',
                      style: TextStyle(color: Colors.orange.shade400, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.28)),
                  ),
                  child: Text(
                    '✅ $todayLabel',
                    style: TextStyle(color: Colors.orange.shade300, fontSize: 9.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // ── Quizzes Created ──
        Expanded(
          child: _StatTile(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _kBlue.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.folder_rounded, color: _kBlue, size: 17),
                ),
                const SizedBox(height: 7),
                Text('Quizzes Created',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 10.5, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                  '$totalQuizzes',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text('Total', style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // ── Questions Studied ──
        Expanded(
          child: _StatTile(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _kGreen.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.check_circle_rounded, color: _kGreen, size: 17),
                ),
                const SizedBox(height: 7),
                Text('Questions Studied',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 10.5, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                  '$totalQuestions',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text('Total', style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final Widget child;
  final bool isDark;
  const _StatTile({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? _kCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? _kBorder : Colors.grey.shade200),
        boxShadow: isDark
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Deck List Tile
// ─────────────────────────────────────────────────────────────────────────────

class _DeckListTile extends StatelessWidget {
  final QuizModel quiz;
  const _DeckListTile({required this.quiz});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/quiz/${quiz.id}'),
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: isDark ? _kCard : Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: isDark ? _kBorder : Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kPurple, _kIndigo],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quiz.title,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if ((quiz.category ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(quiz.category!,
                          style: const TextStyle(color: _kIndigo, fontSize: 10.5, fontWeight: FontWeight.w600)),
                    ],
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.help_outline_rounded, size: 10, color: Colors.grey.shade500),
                        const SizedBox(width: 2),
                        Text('${quiz.questionIds.length} Questions',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 9.5)),
                        const SizedBox(width: 8),
                        Icon(Icons.play_circle_outline_rounded, size: 10, color: Colors.grey.shade500),
                        const SizedBox(width: 2),
                        Text('Studied ${quiz.studyCount ?? 0} times',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 9.5)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 36, height: 36,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: (quiz.averageScore ?? 0) / 100,
                      strokeWidth: 3,
                      backgroundColor: Colors.grey.shade700,
                      valueColor: const AlwaysStoppedAnimation<Color>(_kGreen),
                    ),
                    Text(
                      '${(quiz.averageScore ?? 0).toInt()}%',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500, size: 19),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI Promo Card
// ─────────────────────────────────────────────────────────────────────────────

class _AiPromoCard extends StatelessWidget {
  final bool isOnline;
  const _AiPromoCard({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isOnline ? () => context.go('/ai-generator') : null,
        mouseCursor: isOnline ? SystemMouseCursors.click : SystemMouseCursors.basic,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E293B),
                const Color(0xFF6D28D9).withValues(alpha: 0.45),
              ],
            ),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: _kPurple.withValues(alpha: 0.30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_kPurple, _kIndigo]),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'AI Quiz Generator',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Paste notes or upload PDFs to generate smart flashcards instantly with AI.',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.60), fontSize: 11.5, height: 1.4),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Try AI Generator',
                    style: TextStyle(
                      color: isOnline ? _kPurple : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded,
                      color: isOnline ? _kPurple : Colors.grey, size: 13),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Continue Learning Banner
// ─────────────────────────────────────────────────────────────────────────────

class _ContinueLearningBanner extends StatelessWidget {
  final bool isOnline;
  const _ContinueLearningBanner({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? _kCard : Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: isDark ? _kBorder : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kPurple, _kIndigo]),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Elevate your learning with AI',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Get personalized quizzes and smart flashcards tailored to your needs.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isOnline ? () => context.go('/ai-generator') : null,
              mouseCursor: isOnline ? SystemMouseCursors.click : SystemMouseCursors.basic,
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isOnline
                      ? const LinearGradient(colors: [_kPurple, _kIndigo])
                      : null,
                  color: isOnline ? null : Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text('Start with AI',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11.5)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty Decks
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyDecks extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyDecks({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? _kCard : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: isDark ? _kBorder : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.folder_open_rounded, size: 40, color: Colors.grey.shade500),
          const SizedBox(height: 8),
          Text('No study decks yet',
              style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Create your first deck to get started!',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Create Quiz'),
          ),
        ],
      ),
    );
  }
}
