import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/quiz_provider.dart';
import '../../models/quiz_model.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/responsive_layout.dart';

// ── Design Tokens (mirror home_screen.dart tokens) ────────────────────────────
const _kCard   = Color(0xFF1E293B);
const _kBorder = Color(0xFF334155);
const _kGreen  = Color(0xFF22C55E);
const _kPurple = Color(0xFF8B5CF6);
const _kIndigo = Color(0xFF6366F1);

class StudyModeScreen extends ConsumerWidget {
  const StudyModeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    if (userAsync.isLoading) return const PageSkeleton(list: true);

    final user = userAsync.valueOrNull;
    if (user == null) return const PageSkeleton(list: true);

    final quizzesAsync = ref.watch(userQuizzesProvider(user.id));

    return quizzesAsync.when(
      data: (quizzes) {
        final quizzesWithQuestions =
            quizzes.where((q) => q.questionIds.isNotEmpty).toList();
        return _buildContent(context, quizzes, quizzesWithQuestions);
      },
      loading: () => const PageSkeleton(list: true),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error loading quizzes: $e'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(userQuizzesProvider(user.id).notifier).refreshQuizzes(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<QuizModel> quizzes,
    List<QuizModel> quizzesWithQuestions,
  ) {
    final studiedCount = quizzes.fold<int>(0, (s, q) => s + (q.studyCount ?? 0));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);
    final maxWidth = isDesktop ? 820.0 : double.infinity;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 16,
        vertical: 20,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Plain Title Header ────────────────────────────────────
              Text(
                'Study Mode',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose a quiz to start studying',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // ── Stat Tiles ────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      isDark: isDark,
                      icon: Icons.folder_outlined,
                      value: '${quizzesWithQuestions.length}',
                      label: 'Available',
                      sublabel: 'Ready to study',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      isDark: isDark,
                      icon: Icons.school_outlined,
                      value: '$studiedCount',
                      label: 'Studied',
                      sublabel: 'Completed',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Choose a Study Mode ───────────────────────────────────
              Text(
                'Choose a Study Mode',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _StudyModeCard(
                icon: Icons.style_rounded,
                iconBg: const Color(0xFF78350F),
                iconColor: const Color(0xFFFBBF24),
                title: 'Flashcards',
                subtitle: 'Flip cards to test your memory',
                accentColor: const Color(0xFF92400E),
                cardBg: const Color(0xFF1C1207),
                borderColor: const Color(0xFF78350F),
                onTap: quizzesWithQuestions.isNotEmpty
                    ? () => context.push('/study/flashcard/${quizzesWithQuestions.first.id}')
                    : null,
              ),
              const SizedBox(height: 10),
              _StudyModeCard(
                icon: Icons.quiz_rounded,
                iconBg: const Color(0xFF14532D),
                iconColor: const Color(0xFF4ADE80),
                title: 'Quiz Mode',
                subtitle: 'Multiple choice questions with scoring',
                accentColor: const Color(0xFF166534),
                cardBg: const Color(0xFF071C10),
                borderColor: const Color(0xFF14532D),
                onTap: quizzesWithQuestions.isNotEmpty
                    ? () => context.push('/study/quiz/${quizzesWithQuestions.first.id}')
                    : null,
              ),
              const SizedBox(height: 28),

              // ── Select a Quiz to Study ────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select a Quiz to Study',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => context.go('/my-quizzes'),
                      child: Text(
                        'View All Quizzes',
                        style: TextStyle(
                          color: _kIndigo,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (quizzesWithQuestions.isEmpty)
                _buildEmptyState(context, isDark)
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: quizzesWithQuestions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final quiz = quizzesWithQuestions[index];
                    return _QuizStudyCard(quiz: quiz, isDark: isDark);
                  },
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? _kCard : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? _kBorder : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.school_outlined, size: 56, color: Colors.grey.shade500),
          const SizedBox(height: 16),
          Text('No quizzes available',
              style: TextStyle(
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 8),
          Text(
            'Create quizzes with questions to start studying',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => context.push('/create-quiz'),
            icon: const Icon(Icons.add),
            label: const Text('Create Quiz'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat Tile
// ─────────────────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String value;
  final String label;
  final String sublabel;

  const _StatTile({
    required this.isDark,
    required this.icon,
    required this.value,
    required this.label,
    required this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? _kCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? _kBorder : Colors.grey.shade200),
        boxShadow: isDark
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
      ),
      child: Column(
        children: [
          Icon(icon,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade500, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(sublabel, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Study Mode Card (Flashcards / Quiz Mode)
// ─────────────────────────────────────────────────────────────────────────────

class _StudyModeCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color accentColor;
  final Color cardBg;
  final Color borderColor;
  final VoidCallback? onTap;

  const _StudyModeCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.cardBg,
    required this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        mouseCursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedOpacity(
          opacity: onTap == null ? 0.5 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: isDark ? cardBg : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? borderColor : Colors.grey.shade200),
              boxShadow: isDark
                  ? null
                  : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? iconBg : iconBg.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: isDark ? iconColor : iconBg, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quiz Study Card (with action buttons)
// ─────────────────────────────────────────────────────────────────────────────

class _QuizStudyCard extends StatelessWidget {
  final QuizModel quiz;
  final bool isDark;
  const _QuizStudyCard({required this.quiz, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? _kCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? _kBorder : Colors.grey.shade200),
        boxShadow: isDark
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
      ),
      child: Column(
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              children: [
                // Quiz icon
                Container(
                  width: 46, height: 46,
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
                const SizedBox(width: 12),
                // Title + category + info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quiz.title,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((quiz.category ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          quiz.category!,
                          style: const TextStyle(
                              color: _kIndigo, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.help_outline_rounded, size: 11, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Text(
                            '${quiz.questionIds.length} Questions',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 10.5),
                          ),
                          const SizedBox(width: 10),
                          Icon(Icons.play_circle_outline_rounded, size: 11, color: Colors.grey.shade500),
                          const SizedBox(width: 3),
                          Text(
                            'Studied ${quiz.studyCount ?? 0} times',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 10.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Progress + 3-dot menu
                Column(
                  children: [
                    SizedBox(
                      width: 38, height: 38,
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
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    _QuizMenuButton(quiz: quiz),
                  ],
                ),
              ],
            ),
          ),

          // Divider
          Divider(
            height: 1,
            color: isDark ? _kBorder : Colors.grey.shade200,
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: _ActionBtn(
                    label: 'Study with Flashcards',
                    icon: Icons.style_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF8C00), Color(0xFFFF6B00)],
                    ),
                    shadowColor: Colors.orange,
                    onPressed: () => context.push('/study/flashcard/${quiz.id}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionBtn(
                    label: 'Take Quiz',
                    icon: Icons.quiz_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                    ),
                    shadowColor: Colors.green,
                    onPressed: () => context.push('/study/quiz/${quiz.id}'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizMenuButton extends StatelessWidget {
  final QuizModel quiz;
  const _QuizMenuButton({required this.quiz});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey.shade500),
      padding: EdgeInsets.zero,
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'detail', child: Text('View Details')),
        const PopupMenuItem(value: 'flashcard', child: Text('Study Flashcards')),
        const PopupMenuItem(value: 'quiz', child: Text('Take Quiz')),
      ],
      onSelected: (val) {
        if (val == 'detail') context.push('/quiz/${quiz.id}');
        if (val == 'flashcard') context.push('/study/flashcard/${quiz.id}');
        if (val == 'quiz') context.push('/study/quiz/${quiz.id}');
      },
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Gradient gradient;
  final Color shadowColor;
  final VoidCallback onPressed;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.shadowColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: shadowColor.withValues(alpha: 0.30),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 15),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
