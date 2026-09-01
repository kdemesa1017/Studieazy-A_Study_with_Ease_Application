import 'package:flutter/material.dart';

class LegalPolicyDialog extends StatefulWidget {
  final VoidCallback? onAccept;
  final bool isMandatoryAcceptance;

  const LegalPolicyDialog({
    super.key,
    this.onAccept,
    this.isMandatoryAcceptance = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    VoidCallback? onAccept,
    bool isMandatoryAcceptance = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => LegalPolicyDialog(
        onAccept: onAccept,
        isMandatoryAcceptance: isMandatoryAcceptance,
      ),
    );
  }

  @override
  State<LegalPolicyDialog> createState() => _LegalPolicyDialogState();
}

class _LegalPolicyDialogState extends State<LegalPolicyDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
          maxWidth: 640,
          maxHeight: 720,
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
                      Icons.shield_outlined,
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
                          'Legal & Privacy Policy',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Studieazy • Effective August 2026',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textSecondary),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),

            // ── Tab Bar ───────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
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
                  Tab(text: 'Terms of Service'),
                  Tab(text: 'Privacy Policy'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Tab Contents ──────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTermsTab(cardBg, cardBorder, textPrimary, textSecondary, primaryColor),
                  _buildPrivacyTab(cardBg, cardBorder, textPrimary, textSecondary, primaryColor),
                ],
              ),
            ),

            // ── Footer Actions ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
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
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          color: textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (widget.isMandatoryAcceptance || widget.onAccept != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          widget.onAccept?.call();
                          Navigator.of(context).pop(true);
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline_rounded, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'I Accept',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: Terms of Service ────────────────────────────────────────────────

  Widget _buildTermsTab(
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
    Color accentColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPolicyCard(
            cardBg: cardBg,
            cardBorder: cardBorder,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            icon: Icons.menu_book_rounded,
            accentColor: accentColor,
            title: '1. Educational Purpose',
            content:
                'Studieazy is designed as an interactive self-learning tool. It offers flashcards, automated quizzes, and AI-powered study assistance to help students and professionals enhance memory retention and academic performance.',
          ),
          const SizedBox(height: 12),
          _buildPolicyCard(
            cardBg: cardBg,
            cardBorder: cardBorder,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            icon: Icons.account_circle_outlined,
            accentColor: Colors.blue,
            title: '2. User Accounts & Verification',
            content:
                'Users must provide a valid email address and complete email OTP verification to maintain account security. You are responsible for safeguarding your login credentials and all activities occurring under your account.',
          ),
          const SizedBox(height: 12),
          _buildPolicyCard(
            cardBg: cardBg,
            cardBorder: cardBorder,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            icon: Icons.auto_awesome_rounded,
            accentColor: Colors.purple,
            title: '3. AI Quiz Generation & Content Rules',
            content:
                'When uploading documents (PDF, TXT, DOCX) or providing study materials, you confirm that you have the right to use the material. Content containing hate speech, illegal material, malicious scripts, or severe copyright infringement is strictly prohibited.',
          ),
          const SizedBox(height: 12),
          _buildPolicyCard(
            cardBg: cardBg,
            cardBorder: cardBorder,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            icon: Icons.verified_user_outlined,
            accentColor: Colors.green,
            title: '4. Service Availability & Offline Usage',
            content:
                'Studieazy provides offline caching capabilities allowing you to study downloaded flashcards without internet. However, AI quiz generation and cloud syncing require an active internet connection.',
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Privacy Policy ──────────────────────────────────────────────────

  Widget _buildPrivacyTab(
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
    Color accentColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPolicyCard(
            cardBg: cardBg,
            cardBorder: cardBorder,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            icon: Icons.data_usage_rounded,
            accentColor: Colors.teal,
            title: '1. Information We Collect',
            content:
                '• Profile Data: Full name, email address, optional academic level & school.\n• Study Analytics: Daily streaks, quiz completion counts, average scores, and question responses.\n• Uploaded Documents: Temporary text extracted from notes to produce your study questions.',
          ),
          const SizedBox(height: 12),
          _buildPolicyCard(
            cardBg: cardBg,
            cardBorder: cardBorder,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            icon: Icons.psychology_rounded,
            accentColor: Colors.deepPurple,
            title: '2. How AI (Google Gemini) Processes Your Data',
            content:
                'When generating quizzes, your document text is transmitted via encrypted HTTPS directly to the Google Gemini API solely for prompt evaluation. We DO NOT sell, lease, or monetize your study notes, personal data, or quiz content to third-party advertisers.',
          ),
          const SizedBox(height: 12),
          _buildPolicyCard(
            cardBg: cardBg,
            cardBorder: cardBorder,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            icon: Icons.lock_outline_rounded,
            accentColor: Colors.orange,
            title: '3. Data Security & Storage',
            content:
                'User data and quizzes are secured within Google Firebase Firestore with strict access control rules. Only authenticated owners have read and write access to their respective study sets.',
          ),
          const SizedBox(height: 12),
          _buildPolicyCard(
            cardBg: cardBg,
            cardBorder: cardBorder,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            icon: Icons.delete_forever_outlined,
            accentColor: Colors.redAccent,
            title: '4. Your Rights & Data Deletion',
            content:
                'You retain full ownership of your created quizzes. You can modify, edit, or permanently delete individual questions, decks, or your entire account at any time directly through the app settings.',
          ),
        ],
      ),
    );
  }

  // ── Helper Card ────────────────────────────────────────────────────────────

  Widget _buildPolicyCard({
    required Color cardBg,
    required Color cardBorder,
    required Color textPrimary,
    required Color textSecondary,
    required IconData icon,
    required Color accentColor,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  content,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 12.5,
                    height: 1.45,
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