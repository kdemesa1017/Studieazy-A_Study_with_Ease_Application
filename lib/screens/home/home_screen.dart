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
        const SizedBox(height: 16),

        // Quick Actions Shortcuts
        const _QuickActions(),
        const SizedBox(height: 20),

        // Progress Overview
        const _SectionHeader(title: 'Progress Overview'),
        const SizedBox(height: 10),
        _ProgressStats(
          streakCount: streakCount,
          totalQuizzes: totalQuizzes,
          totalQuestions: totalQuestions,
        ),
        const SizedBox(height: 24),

        // Recent Study Decks & AI Promo Card (Responsive)
        if (!isDesktop) ...[
          // Mobile: Full-width AI Promo Banner
          _AiPromoCard(isOnline: isOnline),
          const SizedBox(height: 20),

          // Mobile: Recent Study Decks Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionHeader(title: 'Recent Study Decks'),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => context.go('/my-quizzes'),
                  child: const Text(
                    'View All →',
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
          const SizedBox(height: 10),

          // Mobile: Full-width Deck Tiles (no cramped side-by-side squeezing)
          recentQuizzes.isEmpty
              ? _EmptyDecks(onTap: () => context.go('/create-quiz'))
              : Column(
                  children: recentQuizzes
                      .take(4)
                      .map((quiz) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _DeckListTile(quiz: quiz),
                          ))
                      .toList(),
                ),
        ] else ...[
          // Desktop: 2-Column Wide Layout
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionHeader(title: 'Recent Study Decks'),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => context.go('/my-quizzes'),
                  child: const Text(
                    'View All →',
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
                flex: 6,
                child: recentQuizzes.isEmpty
                    ? _EmptyDecks(onTap: () => context.go('/create-quiz'))
                    : Column(
                        children: recentQuizzes
                            .take(4)
                            .map((quiz) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _DeckListTile(quiz: quiz),
                                ))
                            .toList(),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: _AiPromoCard(isOnline: isOnline),
              ),
            ],
          ),
        ],
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
// Hero Banner  (full-width, time-aware, glowing gradient)
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final dynamic user;
  const _HeroBanner({required this.user});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning ☀️';
    if (h < 17) return 'Good Afternoon 📚';
    return 'Good Evening 🌙';
  }

  @override
  Widget build(BuildContext context) {
    final firstName = (user?.name ?? 'Student').split(' ').first;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          // Glowing orb — top right
          Positioned(
            right: -24, top: -24,
            child: Container(
              width: 170, height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6366F1).withValues(alpha: 0.14),
              ),
            ),
          ),
          // Glowing orb — bottom left
          Positioned(
            left: -20, bottom: -20,
            child: Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
              ),
            ),
          ),
          // Sparkles
          Positioned(right: 55, top: 20,
            child: Icon(Icons.auto_awesome, color: Colors.white.withValues(alpha: 0.22), size: 16)),
          Positioned(right: 20, top: 48,
            child: Icon(Icons.star_rounded, color: Colors.white.withValues(alpha: 0.14), size: 10)),
          Positioned(right: 90, bottom: 22,
            child: Icon(Icons.auto_awesome, color: Colors.white.withValues(alpha: 0.14), size: 12)),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
                  ),
                  child: Text(
                    _greeting,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  firstName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ready to level up your knowledge today?',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _HeroActionBtn(
                        label: '✨  Generate with AI',
                        filled: true,
                        onTap: () => context.go('/ai-generator'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroActionBtn(
                        label: '+  Create Deck',
                        filled: false,
                        onTap: () => context.go('/create-quiz'),
                      ),
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

class _HeroActionBtn extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _HeroActionBtn({required this.label, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            gradient: filled
                ? const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)])
                : null,
            color: filled ? null : Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(11),
            border: filled
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.28)),
            boxShadow: filled
                ? [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.45), blurRadius: 12, offset: const Offset(0, 4))]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Actions (horizontal scrollable chip shortcuts)
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final actions = [
      (icon: Icons.auto_awesome_rounded, label: 'AI Generate', color: _kPurple, route: '/ai-generator'),
      (icon: Icons.folder_rounded,       label: 'My Quizzes',  color: _kBlue,   route: '/my-quizzes'),
      (icon: Icons.school_rounded,       label: 'Study Mode',  color: _kGreen,  route: '/study'),
      (icon: Icons.add_rounded,          label: 'Create Deck', color: _kIndigo, route: '/create-quiz'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: actions.map((a) {
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.go(a.route),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? _kCard : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? _kBorder : Colors.grey.shade200,
                    ),
                    boxShadow: isDark
                        ? null
                        : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: a.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(a.icon, color: a.color, size: 15),
                      ),
                      const SizedBox(width: 9),
                      Text(
                        a.label,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}



// ─────────────────────────────────────────────────────────────────────────────
// Progress Stats (3 cards)
// ─────────────────────────────────────────────────────────────────────────────

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
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF6B35), _kOrange]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'Streak',
                  style: TextStyle(color: Colors.orange.shade400, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$streakCount',
                      style: const TextStyle(color: Color(0xFFFF8C00), fontSize: 22, fontWeight: FontWeight.bold, height: 1),
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
                  child: const Icon(Icons.folder_rounded, color: _kBlue, size: 18),
                ),
                const SizedBox(height: 8),
                Text('Quizzes',
                    style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '$totalQuizzes',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text('Created', style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
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
                  child: const Icon(Icons.check_circle_rounded, color: _kGreen, size: 18),
                ),
                const SizedBox(height: 8),
                Text('Questions',
                    style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '$totalQuestions',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text('Studied', style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
// Deck List Tile (Spacious Full-Width Design)
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
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: isDark ? _kCard : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? _kBorder : Colors.grey.shade200),
            boxShadow: isDark
                ? null
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kPurple, _kIndigo],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quiz.title,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if ((quiz.category ?? '').isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _kIndigo.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              quiz.category!,
                              style: const TextStyle(color: _kIndigo, fontSize: 10, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Icon(Icons.help_outline_rounded, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Text('${quiz.questionIds.length} Questions',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 38, height: 38,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: (quiz.averageScore ?? 0) / 100,
                      strokeWidth: 3.5,
                      backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(_kGreen),
                    ),
                    Text(
                      '${(quiz.averageScore ?? 0).toInt()}%',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI Promo Card (Modern Eye-Catching Banner)
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E1B4B),
                Color(0xFF4338CA),
                Color(0xFF6D28D9),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4338CA).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Quiz Generator',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: -0.2),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Powered by Google Gemini AI',
                          style: TextStyle(color: Color(0xFFA5B4FC), fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Paste notes or upload PDFs & Word documents to generate complete study decks in seconds.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Generate Flashcards',
                      style: TextStyle(
                        color: isOnline ? const Color(0xFF4338CA) : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded,
                        color: isOnline ? const Color(0xFF4338CA) : Colors.grey, size: 14),
                  ],
                ),
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
