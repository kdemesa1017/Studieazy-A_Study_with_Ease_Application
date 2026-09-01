import 'package:flutter/material.dart';

class UserGuideDialog extends StatefulWidget {
  final int initialTabIndex;

  const UserGuideDialog({
    super.key,
    this.initialTabIndex = 0,
  });

  static Future<void> show(BuildContext context, {int initialTabIndex = 0}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => UserGuideDialog(initialTabIndex: initialTabIndex),
    );
  }

  @override
  State<UserGuideDialog> createState() => _UserGuideDialogState();
}

class _UserGuideDialogState extends State<UserGuideDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    const primaryColor = Color(0xFF5C4EE8);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final cardBg = isDark
        ? const Color(0xFF0F172A).withValues(alpha: 0.6)
        : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 680,
          maxHeight: 740,
        ),
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Studieazy Guide & Help',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Comprehensive guide, tips & frequently asked questions',
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ── Search & Filter ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: TextField(
                controller: _searchController,
                style: TextStyle(fontSize: 13, color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search guide, topics or questions...',
                  hintStyle: TextStyle(fontSize: 13, color: isDark ? Colors.white38 : Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: cardBg,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: primaryColor, width: 1.5),
                  ),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim().toLowerCase());
                },
              ),
            ),

            const SizedBox(height: 8),

            // ── Tab Bar ───────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cardBorder),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: textSecondary,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.auto_stories_rounded, size: 18),
                    text: 'User Guide',
                  ),
                  Tab(
                    icon: Icon(Icons.quiz_rounded, size: 18),
                    text: 'Frequently Asked Questions',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Tab Contents ──────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildUserGuideTab(cardBg, cardBorder, textPrimary, textSecondary, primaryColor, isDark),
                  _buildFaqTab(cardBg, cardBorder, textPrimary, textSecondary, primaryColor, isDark),
                ],
              ),
            ),

            // ── Footer ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161F30) : const Color(0xFFF1F5F9),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                border: Border(top: BorderSide(color: cardBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: cardBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Close Guide',
                        style: TextStyle(
                          color: textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: User Guide ──────────────────────────────────────────────────────

  Widget _buildUserGuideTab(
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
    Color primaryColor,
    bool isDark,
  ) {
    final guideSections = [
      _GuideSectionData(
        icon: Icons.rocket_launch_rounded,
        color: const Color(0xFF6366F1),
        title: '1. Getting Started with Studieazy',
        steps: [
          'Create an account with a valid email and verify with the 6-digit OTP code sent to your inbox.',
          'Explore your Dashboard with real-time statistics including created quizzes, study streak, and question count.',
          'Navigate smoothly between Home, Manual Quiz Creator, AI Generator, My Quizzes, and Profile.',
          'The app automatically matches your device’s Light or Dark system theme for comfortable day/night reading.',
        ],
      ),
      _GuideSectionData(
        icon: Icons.auto_awesome_rounded,
        color: const Color(0xFFFF8C42),
        title: '2. AI Quiz Generator (Gemini Powered)',
        steps: [
          'Tap "AI Generator" in the bottom navigation bar.',
          'Upload documents, lectures, or syllabi (supports PDF, DOCX, TXT, and study notes up to 10MB).',
          'Select your target question count (from 1 to 50 questions) using the interactive slider or number input.',
          'Tap "Generate with AI" — Gemini analyzes key topics, definitions, and concepts automatically.',
          'Review the generated questions, adjust answers if desired, and tap "Save Quiz" to add to your library.',
        ],
      ),
      _GuideSectionData(
        icon: Icons.add_circle_outline_rounded,
        color: const Color(0xFF10B981),
        title: '3. Creating Custom Quizzes Manually',
        steps: [
          'Tap the "Create" button on the bottom menu.',
          'Enter a Quiz Title, Category, and Description.',
          'Choose your Quiz Mode:',
          '  • Multiple Choice (MCQ): Standard 4-option quiz with 1 correct choice.',
          '  • Identification: Direct keyword answer, optimal for flashcard memorization.',
          '  • Enumeration: List items in sequence or bulleted keywords.',
          '  • Combine Mode: Mix MCQ, Identification, and Enumeration within a single quiz.',
          'Attach diagrams / visual aids by clicking "Add Image / Diagram (URL)" on any question card.',
          'Tap "Create Quiz" to save locally and sync to the cloud automatically.',
        ],
      ),
      _GuideSectionData(
        icon: Icons.style_rounded,
        color: const Color(0xFFEC4899),
        title: '4. Studying with Flashcards & Quizzes',
        steps: [
          'Open any quiz from "My Quizzes" or Home, then tap "Start Study Mode".',
          'Flashcard Controls:',
          '  • Tap Card: Flips the flashcard between question (front) and answer (back).',
          '  • Swipe Left or tap "Still Learning": Retains the card in your active study queue.',
          '  • Swipe Right or tap "Got it!": Marks the card as mastered.',
          'Desktop/Web Shortcuts: Left Arrow (←) = Still Learning, Right Arrow (→) = Got it!, Click Card = Flip.',
          'Interactive Quiz Mode: Select answers or type keyword solutions with instant validation.',
        ],
      ),
      _GuideSectionData(
        icon: Icons.cloud_sync_rounded,
        color: const Color(0xFF3B82F6),
        title: '5. Offline Support & Cloud Sync',
        steps: [
          'Studieazy caches all your quizzes locally using Hive offline storage.',
          'You can create, review, and study your flashcards even without an active internet connection.',
          'Any changes made offline automatically sync to Firebase Cloud Firestore as soon as your device reconnects.',
        ],
      ),
      _GuideSectionData(
        icon: Icons.admin_panel_settings_rounded,
        color: const Color(0xFF8B5CF6),
        title: '6. Admin Control Center & 2FA Security',
        steps: [
          'Admin accounts feature protected 2-Factor Authentication (2FA).',
          'Before sending an OTP email, a confirmation prompt asks if you wish to proceed, preventing wasted email quota.',
          'Access system health monitors, error logs, user management, backups, and user support tickets in real-time.',
        ],
      ),
    ];

    final filtered = _searchQuery.isEmpty
        ? guideSections
        : guideSections.where((s) {
            final matchTitle = s.title.toLowerCase().contains(_searchQuery);
            final matchSteps = s.steps.any((step) => step.toLowerCase().contains(_searchQuery));
            return matchTitle || matchSteps;
          }).toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(textPrimary, textSecondary);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: filtered.length,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 14),
      itemBuilder: (ctx, index) {
        final section = filtered[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: section.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(section.icon, color: section.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      section.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...section.steps.map(
                (step) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4, right: 8),
                        child: Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: section.color,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          step,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: textSecondary,
                            height: 1.4,
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
      },
    );
  }

  // ── Tab 2: Frequently Asked Questions ──────────────────────────────────────

  Widget _buildFaqTab(
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
    Color primaryColor,
    bool isDark,
  ) {
    final faqList = [
      _FaqItemData(
        question: 'Is Studieazy free to use?',
        answer:
            'Yes! Studieazy is a free educational application. Creating quizzes, studying with spaced repetition flashcards, and generating AI quizzes are available for all registered students and educators.',
      ),
      _FaqItemData(
        question: 'How does the AI Quiz Generator work?',
        answer:
            'Our AI Generator is powered by Google Gemini AI. It reads the key concepts, terms, definitions, and topics from your uploaded documents or text and creates structured multiple-choice, identification, and flashcard sets.',
      ),
      _FaqItemData(
        question: 'Can I add images or diagrams to my questions?',
        answer:
            'Yes! In the Quiz Creator, click "Add Image / Diagram (URL)" on any question card. Paste a public image link (e.g. from Imgur, Cloudinary, or web URL) to display diagrams directly on flashcards and quiz cards.',
      ),
      _FaqItemData(
        question: 'Can I study without an internet connection?',
        answer:
            'Absolutely. All your quizzes are stored in your device’s local cache (Hive). You can review flashcards offline, and your study sessions will sync with the cloud once you reconnect.',
      ),
      _FaqItemData(
        question: 'How do I report a bug or suggest a feature?',
        answer:
            'Go to Profile ➔ Help & Support ➔ tap "Contact Support" or "Report a Bug". Enter your subject and details. Our admin team will receive and review your ticket directly.',
      ),
      _FaqItemData(
        question: 'How do I reset my password?',
        answer:
            'On the Login screen or in Profile ➔ Account & Security, tap "Forgot password?". Enter your registered email address to receive a secure password reset link from Firebase.',
      ),
      _FaqItemData(
        question: 'How does Dark Mode work?',
        answer:
            'Studieazy automatically detects your device’s system brightness settings. You can also customize your preference anytime in Profile ➔ Study Preferences.',
      ),
    ];

    final filtered = _searchQuery.isEmpty
        ? faqList
        : faqList.where((item) {
            final matchQ = item.question.toLowerCase().contains(_searchQuery);
            final matchA = item.answer.toLowerCase().contains(_searchQuery);
            return matchQ || matchA;
          }).toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(textPrimary, textSecondary);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: filtered.length,
      separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
      itemBuilder: (ctx, index) {
        final item = filtered[index];
        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorder),
            ),
            child: ExpansionTile(
              leading: const Icon(
                Icons.help_outline_rounded,
                color: Color(0xFF6366F1),
                size: 20,
              ),
              title: Text(
                item.question,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.answer,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(Color textPrimary, Color textSecondary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: textSecondary),
          const SizedBox(height: 12),
          Text(
            'No matching topics found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try searching for another keyword or clear the search field.',
            style: TextStyle(fontSize: 12, color: textSecondary),
          ),
        ],
      ),
    );
  }
}

class _GuideSectionData {
  final IconData icon;
  final Color color;
  final String title;
  final List<String> steps;

  _GuideSectionData({
    required this.icon,
    required this.color,
    required this.title,
    required this.steps,
  });
}

class _FaqItemData {
  final String question;
  final String answer;

  _FaqItemData({
    required this.question,
    required this.answer,
  });
}
