import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/quiz_provider.dart';
import '../../models/quiz_model.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/responsive_layout.dart';

class MyQuizzesScreen extends ConsumerStatefulWidget {
  const MyQuizzesScreen({super.key});

  @override
  ConsumerState<MyQuizzesScreen> createState() => _MyQuizzesScreenState();
}

class _MyQuizzesScreenState extends ConsumerState<MyQuizzesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All'; // 'All', 'Flashcards', 'Quiz', 'Enumeration', 'Identification'
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final userAsync = ref.watch(currentUserProvider);

    if (userAsync.isLoading) return const PageSkeleton(list: true);

    final user = userAsync.valueOrNull;
    if (user == null) return const PageSkeleton(list: true);

    final quizzesAsync = ref.watch(userQuizzesProvider(user.id));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F121E) : const Color(0xFFF6F7FA),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create-quiz'),
        backgroundColor: const Color(0xFF5C4EE8),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Create Quiz',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: quizzesAsync.when(
          data: (allQuizzes) {
            // Apply search & mode filter
            final filteredList = allQuizzes.where((q) {
              // Search query check
              final query = _searchController.text.trim().toLowerCase();
              if (query.isNotEmpty) {
                final matchTitle = q.title.toLowerCase().contains(query);
                final matchDesc = q.description?.toLowerCase().contains(query) ?? false;
                final matchCat = q.category?.toLowerCase().contains(query) ?? false;
                if (!matchTitle && !matchDesc && !matchCat) return false;
              }

              // Mode filter check (if user picked a filter chip)
              if (_selectedFilter != 'All') {
                // Check category or filter match
                final modeLabel = _selectedFilter.toLowerCase();
                if (q.category != null && q.category!.toLowerCase().contains(modeLabel)) {
                  return true;
                }
                // Also match title/description keywords for mode
                if (q.title.toLowerCase().contains(modeLabel)) return true;
                if (q.description?.toLowerCase().contains(modeLabel) ?? false) return true;
              }
              return true;
            }).toList();

            // Stats calculation
            final totalQuizzes = allQuizzes.length;
            int totalSessions = 0;
            double sumAvgScore = 0;
            int quizzesWithScores = 0;

            for (final q in allQuizzes) {
              totalSessions += q.studyCount ?? 0;
              if (q.averageScore != null && q.averageScore! > 0) {
                sumAvgScore += q.averageScore!;
                quizzesWithScores++;
              }
            }

            final overallAvgScore = quizzesWithScores > 0
                ? (sumAvgScore / quizzesWithScores * 100).round()
                : 0;

            final avatarInitial = (user.name.isNotEmpty)
                ? user.name[0].toUpperCase()
                : (user.email.isNotEmpty ? user.email[0].toUpperCase() : 'U');

            return RefreshIndicator(
              onRefresh: () async {
                await ref.read(userQuizzesProvider(user.id).notifier).refreshQuizzes();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header Row ──────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'My Quizzes',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF7C6FF7), Color(0xFF5C4EE8)],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              avatarInitial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Motivational Banner Card ─────────────────────────────
                    _buildBannerCard(isDark),

                    const SizedBox(height: 16),

                    // ── Quick Stats Grid ─────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatTile(
                            context: context,
                            icon: Icons.school_outlined,
                            iconColor: const Color(0xFF7C6FF7),
                            value: '$totalQuizzes',
                            label: 'Quizzes',
                            sublabel: 'Total',
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatTile(
                            context: context,
                            icon: Icons.quiz_outlined,
                            iconColor: const Color(0xFF3B82F6),
                            value: '$totalSessions',
                            label: 'Study Sessions',
                            sublabel: 'Completed',
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatTile(
                            context: context,
                            icon: Icons.trending_up_rounded,
                            iconColor: const Color(0xFF10B981),
                            value: '$overallAvgScore%',
                            label: 'Average Score',
                            sublabel: 'Keep it up!',
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Study Modes Section ──────────────────────────────────
                    Text(
                      'Study Modes',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose a mode to create or study',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2x2 Modes Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildModeCard(
                            title: 'Flashcards',
                            subtitle: 'Review using interactive flashcards',
                            icon: Icons.style_rounded,
                            color: const Color(0xFFF97316),
                            isDark: isDark,
                            onTap: () => setState(() => _selectedFilter = 'Flashcards'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildModeCard(
                            title: 'Quiz Mode',
                            subtitle: 'Answer multiple choice questions',
                            icon: Icons.quiz_rounded,
                            color: const Color(0xFF10B981),
                            isDark: isDark,
                            onTap: () => setState(() => _selectedFilter = 'Quiz'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildModeCard(
                            title: 'Enumeration',
                            subtitle: 'List items in the correct order',
                            icon: Icons.format_list_numbered_rounded,
                            color: const Color(0xFF3B82F6),
                            isDark: isDark,
                            onTap: () => setState(() => _selectedFilter = 'Enumeration'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildModeCard(
                            title: 'Identification',
                            subtitle: 'Identify items from images or text',
                            icon: Icons.find_in_page_rounded,
                            color: const Color(0xFF8B5CF6),
                            isDark: isDark,
                            onTap: () => setState(() => _selectedFilter = 'Identification'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── Your Quizzes Header & Create New Button ──────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Your Quizzes',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => context.push('/create-quiz'),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Create New'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5C4EE8).withValues(alpha: 0.15),
                            foregroundColor: const Color(0xFF7C6FF7),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Search Bar & Filter Controls ─────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E2337) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search quizzes...',
                                hintStyle: TextStyle(
                                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                                  fontSize: 14,
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                                  size: 20,
                                ),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear_rounded, size: 18),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {});
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showSearch = !_showSearch;
                            });
                          },
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E2337) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Icon(
                              Icons.tune_rounded,
                              color: isDark ? Colors.white70 : Colors.grey.shade600,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Filter Chips Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          'All',
                          'Flashcards',
                          'Quiz',
                          'Enumeration',
                          'Identification',
                        ].map((filter) {
                          final isSelected = _selectedFilter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(filter),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedFilter = filter);
                                }
                              },
                              selectedColor: const Color(0xFF5C4EE8),
                              backgroundColor: isDark
                                  ? const Color(0xFF1E2337)
                                  : Colors.white,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? Colors.white60 : Colors.grey.shade700),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                              side: BorderSide(
                                color: isSelected
                                    ? const Color(0xFF5C4EE8)
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.grey.shade200),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Quiz List ────────────────────────────────────────────
                    if (filteredList.isEmpty)
                      _buildEmptyListState(context, isDark)
                    else if (ResponsiveBreakpoints.isDesktop(context))
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.15,
                        ),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final quiz = filteredList[index];
                          return _buildQuizCard(context, quiz, user.id, isDark);
                        },
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final quiz = filteredList[index];
                          return _buildQuizCard(context, quiz, user.id, isDark);
                        },
                      ),
                  ],
                ),
              ),
            );
          },
          loading: () => const PageSkeleton(list: true),
          error: (e, _) => Center(
            child: Text('Error loading quizzes: $e'),
          ),
        ),
      ),
    );
  }

  // ── Banner Card ───────────────────────────────────────────────────────────

  Widget _buildBannerCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1A1F38), const Color(0xFF12162B)]
              : [const Color(0xFF3F37C9), const Color(0xFF5C4EE8)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5C4EE8).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Text(
                    'Keep learning,',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const Text(
                'Keep growing! 🚀',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 200,
                child: Text(
                  'Create quizzes and study smarter every day.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),

          // Illustration Graphic on Right
          Positioned(
            right: -4,
            bottom: -8,
            child: SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  const Icon(
                    Icons.school_rounded,
                    size: 64,
                    color: Colors.white,
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFB703),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stat Tile ─────────────────────────────────────────────────────────────

  Widget _buildStatTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    required String sublabel,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F38) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            sublabel,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Mode Card Widget ──────────────────────────────────────────────────────

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1F38) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
              ),
              child: Icon(Icons.chevron_right_rounded, color: color, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  // ── Quiz Card Widget ──────────────────────────────────────────────────────

  Widget _buildQuizCard(
    BuildContext context,
    QuizModel quiz,
    String userId,
    bool isDark,
  ) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final scorePercent = quiz.averageScore != null ? (quiz.averageScore! * 100).round() : 0;

    // Determine ring color
    Color gaugeColor;
    if (scorePercent >= 70) {
      gaugeColor = const Color(0xFF10B981);
    } else if (scorePercent >= 40) {
      gaugeColor = const Color(0xFFF97316);
    } else if (scorePercent > 0) {
      gaugeColor = const Color(0xFF3B82F6);
    } else {
      gaugeColor = Colors.grey.shade400;
    }

    return Dismissible(
      key: Key(quiz.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Quiz'),
            content: Text('Are you sure you want to delete "${quiz.title}"?'),
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
      },
      onDismissed: (_) async {
        await ref.read(userQuizzesProvider(userId).notifier).deleteQuiz(quiz.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${quiz.title}" deleted')),
          );
        }
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1F38) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: InkWell(
          onTap: () => context.push('/quiz/${quiz.id}'),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon Tile
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C6FF7), Color(0xFF5C4EE8)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.style_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Title & Category
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quiz.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          if (quiz.category != null && quiz.category!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF5C4EE8).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                quiz.category!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF7C6FF7),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Circular Progress Ring Gauge
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: scorePercent / 100,
                            strokeWidth: 4,
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
                          ),
                          Text(
                            '$scorePercent%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Context Menu Popup
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: isDark ? Colors.white54 : Colors.grey.shade400,
                        size: 20,
                      ),
                      onSelected: (value) async {
                        if (value == 'delete') {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Quiz'),
                              content: Text('Are you sure you want to delete "${quiz.title}"?'),
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
                          if (confirm == true && context.mounted) {
                            await ref
                                .read(userQuizzesProvider(userId).notifier)
                                .deleteQuiz(quiz.id);
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.red, size: 18),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100,
                ),
                const SizedBox(height: 10),

                // Footer Meta Row
                Row(
                  children: [
                    _buildMetaItem(
                      icon: Icons.help_outline_rounded,
                      label: '${quiz.questionIds.length} Questions',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 16),
                    _buildMetaItem(
                      icon: Icons.school_outlined,
                      label: 'Studied ${quiz.studyCount ?? 0} times',
                      isDark: isDark,
                    ),
                    const Spacer(),
                    _buildMetaItem(
                      icon: Icons.calendar_today_rounded,
                      label: dateFormat.format(quiz.createdAt),
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaItem({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 13,
          color: isDark ? Colors.white38 : Colors.grey.shade400,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white54 : Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  // ── Empty List State ──────────────────────────────────────────────────────

  Widget _buildEmptyListState(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.folder_open_outlined,
              size: 64,
              color: isDark ? Colors.white24 : Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No quizzes found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create a quiz or try changing your search filter.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
