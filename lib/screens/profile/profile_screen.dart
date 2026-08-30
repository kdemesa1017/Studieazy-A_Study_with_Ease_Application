import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/quiz_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/legal_policy_dialog.dart';
import '../../widgets/admin_2fa_dialog.dart';
import '../../services/admin_service.dart';

enum ProfileSubView {
  main,
  personalDetails,
  appSettings,
  studyPreferences,
  accountSecurity,
  helpSupport,
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  ProfileSubView _currentView = ProfileSubView.main;

  // Personal details controllers
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _addressController;
  late TextEditingController _bioController;
  late TextEditingController _phoneController;
  late TextEditingController _birthdayController;

  bool _isLoading = false;
  Uint8List? _selectedImageBytes;
  final ImagePicker _picker = ImagePicker();

  // App Settings Toggles
  bool _soundEffects = true;
  bool _hapticFeedback = true;
  bool _animations = true;

  // Study Preferences Toggles & State
  String _defaultStudyMode = 'Flashcards';
  int _defaultQuestionCount = 10;
  bool _shuffleQuestions = true;
  bool _shuffleOptions = false;
  bool _dailyReminder = true;
  final String _reminderTime = '08:00 PM';

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider).valueOrNull;
    _nameController = TextEditingController(text: user?.name ?? '');
    _ageController = TextEditingController(text: user?.age?.toString() ?? '');
    _addressController = TextEditingController(text: user?.address ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _phoneController = TextEditingController(text: '+63 912 345 6789');
    _birthdayController = TextEditingController(text: 'July 30, 2005');

    _nameController.addListener(_onFieldChanged);
    _ageController.addListener(_onFieldChanged);
    _addressController.addListener(_onFieldChanged);
    _bioController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  bool _hasChanges(UserModel? user) {
    if (user == null) return false;
    if (_selectedImageBytes != null) return true;
    if (_nameController.text.trim() != (user.name)) return true;
    if (_ageController.text.trim() != (user.age?.toString() ?? '')) return true;
    if (_addressController.text.trim() != (user.address ?? '')) return true;
    if (_bioController.text.trim() != (user.bio ?? '')) return true;
    return false;
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _ageController.removeListener(_onFieldChanged);
    _addressController.removeListener(_onFieldChanged);
    _bioController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _ageController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — Coming Soon!'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF5C4EE8),
      ),
    );
  }

  Future<void> _showResultModal(
    String title,
    String message,
    bool isSuccess, {
    VoidCallback? onDismiss,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder:
          (ctx) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Theme.of(context).colorScheme.surface,
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
                                ? [Colors.green.shade600, Colors.green.shade800]
                                : [Colors.red.shade600, Colors.red.shade800],
                      ),
                    ),
                    child: Icon(
                      isSuccess
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      size: 40,
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
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        if (onDismiss != null) onDismiss();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isSuccess
                                ? Colors.green.shade600
                                : Colors.red.shade600,
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

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder:
          (context) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Take a photo'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ],
            ),
          ),
    );
    if (source == null) return;

    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;

      setState(() => _isLoading = true);
      final error = await ref
          .read(currentUserProvider.notifier)
          .updateProfile(profileImageBytes: bytes);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (error != null) {
        await _showResultModal('Update Failed', error, false);
      } else {
        await _showResultModal(
          'Photo Updated!',
          'Your profile picture has been updated successfully.',
          true,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      await _showResultModal(
        'Photo Error',
        'Unable to access the selected image. Please try again.',
        false,
      );
    }
  }

  Uint8List? _decodeAvatar(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return base64Decode(value);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveProfile() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (!_hasChanges(user)) return;

    final nameText = _nameController.text.trim();
    if (nameText.isEmpty) {
      await _showResultModal('Validation Error', 'Please enter your full name.', false);
      return;
    }

    final ageText = _ageController.text.trim();
    final age = ageText.isEmpty ? null : int.tryParse(ageText);

    setState(() => _isLoading = true);

    try {
      final error = await ref
          .read(currentUserProvider.notifier)
          .updateProfile(
            name: nameText,
            age: age,
            address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
            bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
            profileImageBytes: _selectedImageBytes,
          );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _selectedImageBytes = null;
      });

      if (error != null) {
        await _showResultModal('Update Failed', error, false);
      } else {
        await _showResultModal('Profile Saved!', 'Your details have been updated successfully.', true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        await _showResultModal('Update Failed', 'Unexpected error occurred while saving profile.', false);
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Logout'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await ref.read(currentUserProvider.notifier).signOut();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Account Data'),
            content: const Text(
              'This will delete all your quizzes and local data. This action cannot be undone.',
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
      final error = await ref.read(currentUserProvider.notifier).clearAllData();
      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
        return;
      }

      final user = ref.read(currentUserProvider).valueOrNull;
      if (user != null) {
        ref.read(searchQueryProvider.notifier).state = '';
        ref.read(currentQuizProvider.notifier).state = null;
        ref.read(currentQuestionsProvider.notifier).state = [];
        ref.invalidate(userQuizzesProvider(user.id));
        ref.invalidate(filteredQuizzesProvider(user.id));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All data deleted successfully.')),
      );
      context.go('/my-quizzes');
    }
  }

  // ── Build Screen ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (userAsync.isLoading) return const ProfileSkeleton();

    final user = userAsync.valueOrNull;
    if (user == null) return const ProfileSkeleton();

    final quizzesAsync = ref.watch(userQuizzesProvider(user.id));
    final allQuizzes = quizzesAsync.valueOrNull ?? [];
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
        : 85; // Default aesthetic value

    final bgColor = isDark ? const Color(0xFF0F121E) : const Color(0xFFF6F7FA);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _buildSubView(user, totalQuizzes, totalSessions, overallAvgScore, isDark),
        ),
      ),
    );
  }

  Widget _buildSubView(dynamic user, int totalQuizzes, int totalSessions, int avgScore, bool isDark) {
    switch (_currentView) {
      case ProfileSubView.main:
        return _buildMainProfile(user, totalQuizzes, totalSessions, avgScore, isDark);
      case ProfileSubView.personalDetails:
        return _buildPersonalDetails(user, isDark);
      case ProfileSubView.appSettings:
        return _buildAppSettings(isDark);
      case ProfileSubView.studyPreferences:
        return _buildStudyPreferences(isDark);
      case ProfileSubView.accountSecurity:
        return _buildAccountSecurity(user, isDark);
      case ProfileSubView.helpSupport:
        return _buildHelpSupport(user, isDark);
    }
  }

  // ── 1. Main Profile Screen ────────────────────────────────────────────────

  Widget _buildMainProfile(dynamic user, int quizzes, int sessions, int avgScore, bool isDark) {
    final storedAvatar = _decodeAvatar(user.profileImageBase64);
    final cardBg = isDark ? const Color(0xFF1A1F38) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtitleColor = isDark ? Colors.white54 : Colors.grey.shade600;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Profile',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                color: isDark ? Colors.white70 : Colors.black87,
                onPressed: () => setState(() => _currentView = ProfileSubView.appSettings),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Avatar & User Info
          GestureDetector(
            onTap: _pickImage,
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF7C6FF7), Color(0xFF5C4EE8)],
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: storedAvatar != null
                      ? Image.memory(storedAvatar, fit: BoxFit.cover)
                      : (user.profileImageUrl != null
                          ? Image.network(user.profileImageUrl!, fit: BoxFit.cover)
                          : Center(
                              child: Text(
                                user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 40,
                                ),
                              ),
                            )),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF5C4EE8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.name,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: titleColor),
          ),
          const SizedBox(height: 2),
          Text(user.email, style: TextStyle(fontSize: 13, color: subtitleColor)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF5C4EE8).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Premium',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF7C6FF7)),
            ),
          ),
          const SizedBox(height: 20),

          // Stats Bar (3 items)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statColumn('$quizzes', 'Quizzes', isDark),
                _statDivider(isDark),
                _statColumn('$sessions', 'Study Sessions', isDark),
                _statDivider(isDark),
                _statColumn('$avgScore%', 'Avg Score', isDark),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Menu Tiles List
          _menuTile(
            icon: Icons.person_outline_rounded,
            title: 'Personal Details',
            subtitle: 'Update your personal information',
            onTap: () => setState(() => _currentView = ProfileSubView.personalDetails),
            isDark: isDark,
          ),
          _menuTile(
            icon: Icons.settings_outlined,
            title: 'App Settings',
            subtitle: 'Customize your app experience',
            onTap: () => setState(() => _currentView = ProfileSubView.appSettings),
            isDark: isDark,
          ),
          _menuTile(
            icon: Icons.tune_rounded,
            title: 'Study Preferences',
            subtitle: 'Set study and quiz preferences',
            onTap: () => setState(() => _currentView = ProfileSubView.studyPreferences),
            isDark: isDark,
          ),
          _menuTile(
            icon: Icons.shield_outlined,
            title: 'Account & Security',
            subtitle: 'Manage your account and security',
            onTap: () => setState(() => _currentView = ProfileSubView.accountSecurity),
            isDark: isDark,
          ),
          if (user.isAdmin)
            _adminMenuTile(
              icon: Icons.admin_panel_settings_rounded,
              title: 'Admin Control Center',
              subtitle: 'System health, errors, support tickets & backups',
              onTap: () {
                Admin2faDialog.show(
                  context,
                  adminUser: user,
                  onVerified: () => context.go('/admin'),
                );
              },
              isDark: isDark,
            ),
          _menuTile(
            icon: Icons.policy_outlined,
            title: 'Terms & Privacy Policy',
            subtitle: 'Terms of service, AI data processing & user rights',
            onTap: () => LegalPolicyDialog.show(context),
            isDark: isDark,
          ),
          _menuTile(
            icon: Icons.help_outline_rounded,
            title: 'Help & Support',
            subtitle: 'Get help and contact support',
            onTap: () => setState(() => _currentView = ProfileSubView.helpSupport),
            isDark: isDark,
          ),
          _menuTile(
            icon: Icons.info_outline_rounded,
            title: 'About',
            subtitle: 'App information and version',
            onTap: () => setState(() => _currentView = ProfileSubView.helpSupport),
            isDark: isDark,
          ),

          const SizedBox(height: 20),

          // Logout Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
              label: const Text(
                'Logout',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── 2. Personal Details Sub-Page ──────────────────────────────────────────

  Widget _buildPersonalDetails(dynamic user, bool isDark) {
    final storedAvatar = _decodeAvatar(user.profileImageBase64);
    final cardBg = isDark ? const Color(0xFF1A1F38) : Colors.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _subHeader('Personal Details', isDark),
            const SizedBox(height: 16),

            // Avatar Header
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF7C6FF7), Color(0xFF5C4EE8)],
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: storedAvatar != null
                          ? Image.memory(storedAvatar, fit: BoxFit.cover)
                          : (user.profileImageUrl != null
                              ? Image.network(user.profileImageUrl!, fit: BoxFit.cover)
                              : Center(
                                  child: Text(
                                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 36,
                                    ),
                                  ),
                                )),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Color(0xFF5C4EE8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            _sectionHeader('Basic Information', isDark),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _detailField('Full Name', _nameController, Icons.person_outline, isDark),
                  _divider(isDark),
                  _detailField('Email', TextEditingController(text: user.email), Icons.email_outlined, isDark, readOnly: true),
                  _divider(isDark),
                  _detailField('Age', _ageController, Icons.calendar_today_outlined, isDark, isNumber: true),
                  _divider(isDark),
                  _detailField('Address', _addressController, Icons.location_on_outlined, isDark),
                  _divider(isDark),
                  _detailField('Bio', _bioController, Icons.info_outline, isDark),
                ],
              ),
            ),

            const SizedBox(height: 20),
            _sectionHeader('More Information', isDark),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _detailField('Phone Number', _phoneController, Icons.phone_outlined, isDark),
                  _divider(isDark),
                  _detailField('Birthday', _birthdayController, Icons.cake_outlined, isDark),
                ],
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: (_isLoading || !_hasChanges(user)) ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C4EE8),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ── 3. App Settings Sub-Page ─────────────────────────────────────────────

  Widget _buildAppSettings(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1A1F38) : Colors.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subHeader('App Settings', isDark),
          const SizedBox(height: 16),

          _sectionHeader('Appearance', isDark),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Consumer(
                  builder: (context, ref, child) {
                    final themeMode = ref.watch(themeModeProvider);
                    final modeLabel = themeMode == ThemeMode.dark
                        ? 'Dark'
                        : (themeMode == ThemeMode.light ? 'Light' : 'System');
                    return ListTile(
                      leading: const Icon(Icons.dark_mode_outlined, size: 20),
                      title: const Text('Theme'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(modeLabel, style: const TextStyle(color: Color(0xFF7C6FF7), fontWeight: FontWeight.w600)),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                      onTap: () {
                        // Toggle theme mode
                        final next = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
                        ref.read(themeModeProvider.notifier).setThemeMode(next);
                      },
                    );
                  },
                ),
                _divider(isDark),
                _settingRow('Color Scheme', 'Purple', Icons.palette_outlined, isDark, onTap: () => _comingSoon('Color Scheme')),
                _divider(isDark),
                _settingRow('Language', 'English', Icons.language_rounded, isDark, onTap: () => _comingSoon('Language')),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _sectionHeader('General', isDark),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _toggleRow('Sound Effects', _soundEffects, Icons.volume_up_outlined, (v) => setState(() => _soundEffects = v), isDark),
                _divider(isDark),
                _toggleRow('Haptic Feedback', _hapticFeedback, Icons.vibration_rounded, (v) => setState(() => _hapticFeedback = v), isDark),
                _divider(isDark),
                _toggleRow('Animations', _animations, Icons.animation_rounded, (v) => setState(() => _animations = v), isDark),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _sectionHeader('Data & Storage', isDark),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _settingRow('Clear Cache', '45.2 MB', Icons.delete_outline_rounded, isDark, onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cache cleared (45.2 MB)')),
                  );
                }),
                _divider(isDark),
                _settingRow('Download Management', '', Icons.download_outlined, isDark, onTap: () => _comingSoon('Download Management')),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _sectionHeader('Other', isDark),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _settingRow('Rate Studieazy', '', Icons.star_outline_rounded, isDark, onTap: () => _comingSoon('Rate Studieazy')),
                _divider(isDark),
                _settingRow('Share Studieazy', '', Icons.share_outlined, isDark, onTap: () => _comingSoon('Share Studieazy')),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── 4. Study Preferences Sub-Page ─────────────────────────────────────────

  Widget _buildStudyPreferences(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1A1F38) : Colors.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subHeader('Study Preferences', isDark),
          const SizedBox(height: 16),

          _sectionHeader('Default Study Mode', isDark),
          const SizedBox(height: 2),
          Text('Choose your default mode when starting a quiz', style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade600)),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _modeRadioTile('Flashcards', 'Review using interactive flashcards', Icons.style_rounded, const Color(0xFF7C6FF7), isDark),
                _divider(isDark),
                _modeRadioTile('Quiz Mode', 'Answer multiple choice questions', Icons.quiz_rounded, const Color(0xFF3B82F6), isDark),
                _divider(isDark),
                _modeRadioTile('Enumeration', 'List items in the correct order', Icons.format_list_numbered_rounded, const Color(0xFFF97316), isDark),
                _divider(isDark),
                _modeRadioTile('Identification', 'Identify items from given options', Icons.find_in_page_rounded, const Color(0xFF10B981), isDark),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _sectionHeader('Quiz Settings', isDark),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _settingRow('Default Question Count', '$_defaultQuestionCount questions', Icons.numbers_rounded, isDark, onTap: () {
                  setState(() {
                    _defaultQuestionCount = _defaultQuestionCount == 10 ? 20 : 10;
                  });
                }),
                _divider(isDark),
                _settingRow('Show Explanations', 'After answering', Icons.menu_book_rounded, isDark, onTap: () => _comingSoon('Explanations')),
                _divider(isDark),
                _toggleRow('Shuffle Questions', _shuffleQuestions, Icons.shuffle_rounded, (v) => setState(() => _shuffleQuestions = v), isDark),
                _divider(isDark),
                _toggleRow('Shuffle Options', _shuffleOptions, Icons.swap_vert_rounded, (v) => setState(() => _shuffleOptions = v), isDark),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _sectionHeader('Learning Reminders', isDark),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _toggleRow('Daily Reminder', _dailyReminder, Icons.alarm_rounded, (v) => setState(() => _dailyReminder = v), isDark),
                _divider(isDark),
                _settingRow('Reminder Time', _reminderTime, Icons.access_time_rounded, isDark, onTap: () => _comingSoon('Reminder Time')),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _modeRadioTile(String mode, String desc, IconData icon, Color color, bool isDark) {
    final isSelected = _defaultStudyMode == mode;
    return ListTile(
      onTap: () => setState(() => _defaultStudyMode = mode),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(mode, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? color : (isDark ? Colors.white : Colors.black87))),
      subtitle: Text(desc, style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade500)),
      trailing: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: isSelected ? color : (isDark ? Colors.white38 : Colors.grey.shade300), width: 2),
          color: isSelected ? color : Colors.transparent,
        ),
        child: isSelected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
      ),
    );
  }

  // ── 5. Account & Security Sub-Page ────────────────────────────────────────

  Widget _buildAccountSecurity(dynamic user, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1A1F38) : Colors.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subHeader('Account & Security', isDark),
          const SizedBox(height: 16),

          _sectionHeader('Account', isDark),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _settingRow('Change Email', user.email, Icons.email_outlined, isDark, onTap: () => _comingSoon('Change Email')),
                _divider(isDark),
                _settingRow('Change Password', 'Update your password', Icons.lock_outline, isDark, onTap: () => _comingSoon('Change Password')),
                _divider(isDark),
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent, size: 20),
                  title: const Text('Delete Account', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Permanently delete your account & data', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.redAccent),
                  onTap: _clearAllData,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _sectionHeader('Security', isDark),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _settingRow('Two-Factor Authentication', 'Not enabled', Icons.security_rounded, isDark, onTap: () => _comingSoon('2FA')),
                _divider(isDark),
                _settingRow('Active Sessions', '2 sessions', Icons.devices_rounded, isDark, onTap: () => _comingSoon('Active Sessions')),
                _divider(isDark),
                _settingRow('Login History', 'View recent activity', Icons.history_rounded, isDark, onTap: () => _comingSoon('Login History')),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── 6. Help & Support Sub-Page ────────────────────────────────────────────

  Widget _buildHelpSupport(dynamic user, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1A1F38) : Colors.white;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subHeader('Help & Support', isDark),
          const SizedBox(height: 16),

          _sectionHeader('Help & Support', isDark),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _settingRow('Frequently Asked Questions', 'Find answers to common questions', Icons.help_outline_rounded, isDark, onTap: () => _comingSoon('FAQ')),
                _divider(isDark),
                _settingRow('Contact Support', "We're here to help you", Icons.support_agent_rounded, isDark, onTap: () => _showSupportTicketDialog(context, 'Account / Support', user, isDark)),
                _divider(isDark),
                _settingRow('Report a Bug', 'Help us improve the app', Icons.bug_report_outlined, isDark, onTap: () => _showSupportTicketDialog(context, 'Bug / Error', user, isDark)),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _sectionHeader('Resources', isDark),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _settingRow('User Guide', 'Learn how to use the app', Icons.article_outlined, isDark, onTap: () => _comingSoon('User Guide')),
                _divider(isDark),
                _settingRow('Privacy Policy', 'Read our privacy policy', Icons.privacy_tip_outlined, isDark, onTap: () => LegalPolicyDialog.show(context)),
                _divider(isDark),
                _settingRow('Terms of Service', 'Read our terms of service', Icons.description_outlined, isDark, onTap: () => LegalPolicyDialog.show(context)),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _sectionHeader('About', isDark),
          const SizedBox(height: 8),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(colors: [Color(0xFF7C6FF7), Color(0xFF5C4EE8)]),
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 12),
                Text('Studieazy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF111827))),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5C4EE8).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF5C4EE8).withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'V0.3.1 (Beta App)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF5C4EE8)),
                  ),
                ),
                const SizedBox(height: 8),
                Text('© 2026 Studieazy. All rights reserved.', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade400)),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showSupportTicketDialog(BuildContext context, String defaultCategory, dynamic user, bool isDark) {
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    String selectedCategory = defaultCategory;
    bool isSubmitting = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Submit Support Request',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Bug / Error', child: Text('Bug / Error Report')),
                        DropdownMenuItem(value: 'Account / Support', child: Text('Account / Login Issue')),
                        DropdownMenuItem(value: 'Flashcard / Quiz', child: Text('Flashcard / Quiz Problem')),
                        DropdownMenuItem(value: 'Feature Request', child: Text('Feature Request')),
                        DropdownMenuItem(value: 'Other', child: Text('Other Feedback')),
                      ],
                      onChanged: (val) {
                        if (val != null) setSheetState(() => selectedCategory = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: subjectCtrl,
                      decoration: InputDecoration(
                        labelText: 'Subject',
                        hintText: 'Brief summary of the issue...',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: messageCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'Provide details so we can fix it quickly...',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5C4EE8),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (subjectCtrl.text.trim().isEmpty || messageCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(content: Text('Please enter a subject and message.')),
                                  );
                                  return;
                                }

                                setSheetState(() => isSubmitting = true);
                                try {
                                  await AdminService.createTicket(
                                    userId: user?.id ?? 'guest',
                                    userEmail: user?.email ?? 'unknown@studieazy.app',
                                    userName: user?.name ?? 'User',
                                    subject: subjectCtrl.text.trim(),
                                    message: messageCtrl.text.trim(),
                                    category: selectedCategory,
                                  );
                                  if (ctx.mounted) {
                                    Navigator.of(ctx).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Support ticket sent! Admin will review it soon.')),
                                    );
                                  }
                                } catch (e) {
                                  if (ctx.mounted) {
                                    setSheetState(() => isSubmitting = false);
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(content: Text('Failed to submit: $e')),
                                    );
                                  }
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Send Report to Support', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Helper Widgets ────────────────────────────────────────────────────────

  Widget _subHeader(String title, bool isDark) {
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() => _currentView = ProfileSubView.main),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2337) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: isDark ? Colors.white70 : Colors.black87),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: titleColor),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white70 : Colors.grey.shade700,
      ),
    );
  }

  Widget _statColumn(String value, String label, bool isDark) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF111827))),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey.shade500)),
      ],
    );
  }

  Widget _statDivider(bool isDark) {
    return Container(
      width: 1,
      height: 30,
      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
    );
  }

  Widget _adminMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF312E81).withValues(alpha: 0.5), const Color(0xFF1E1B4B).withValues(alpha: 0.5)]
              : [const Color(0xFFEEECFF), const Color(0xFFF5F3FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.5)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        title: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'ADMIN ONLY',
                style: TextStyle(
                  color: Color(0xFF6366F1),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF6366F1)),
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final cardBg = isDark ? const Color(0xFF1A1F38) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtitleColor = isDark ? Colors.white38 : Colors.grey.shade500;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF5C4EE8).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF7C6FF7), size: 20),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: titleColor)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: subtitleColor)),
        trailing: Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : Colors.grey.shade400),
      ),
    );
  }

  Widget _settingRow(String title, String value, IconData icon, bool isDark, {required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 20, color: isDark ? Colors.white70 : Colors.grey.shade600),
      title: Text(title, style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value.isNotEmpty)
            Text(value, style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade500)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : Colors.grey.shade400, size: 20),
        ],
      ),
    );
  }

  Widget _toggleRow(String title, bool value, IconData icon, ValueChanged<bool> onChanged, bool isDark) {
    return ListTile(
      leading: Icon(icon, size: 20, color: isDark ? Colors.white70 : Colors.grey.shade600),
      title: Text(title, style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
      trailing: Switch(
        value: value,
        activeTrackColor: const Color(0xFF5C4EE8),
        activeThumbColor: Colors.white,
        onChanged: onChanged,
      ),
    );
  }

  Widget _detailField(String label, TextEditingController controller, IconData icon, bool isDark, {bool readOnly = false, bool isNumber = false}) {
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: isDark ? Colors.white38 : Colors.grey.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: readOnly,
              keyboardType: isNumber ? TextInputType.number : TextInputType.text,
              inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
              style: TextStyle(fontSize: 14, color: titleColor, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey.shade500),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (!readOnly)
            Icon(Icons.edit_outlined, size: 16, color: isDark ? Colors.white38 : Colors.grey.shade400),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Divider(
      height: 1,
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
      indent: 16,
      endIndent: 16,
    );
  }
}
