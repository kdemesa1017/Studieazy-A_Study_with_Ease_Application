import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/legal_policy_dialog.dart';


// ─── Constants ───────────────────────────────────────────────────────────────

const _kPrimary = Color(0xFF5C4EE8);
const _kPrimaryLight = Color(0xFFEEECFF);
const _kBg = Color(0xFFF5F5FF);
const _kTextDark = Color(0xFF1A1A2E);
const _kTextGrey = Color(0xFF8E8EA9);

// ─── Main Widget ─────────────────────────────────────────────────────────────

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with TickerProviderStateMixin {
  int _currentStep = 1; // 1=Welcome, 2=PersonalInfo, 3=AccountDetails, 4=OTP, 5=Success
  bool _isLoading = false;
  bool _agreedToPolicy = false;

  final _formKeyStep2 = GlobalKey<FormState>();
  final _formKeyStep3 = GlobalKey<FormState>();

  // Step 2 Controllers
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _schoolController = TextEditingController();
  String? _selectedGrade;

  // Step 3 Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Step 4 – 6-digit OTP entry
  Timer? _resendTimer;
  int _resendSeconds = 30;
  bool _canResend = false;
  String? _otpError;
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  // Password checks
  bool _hasMinLength = false;
  bool _hasNumber = false;
  bool _hasUpper = false;
  bool _hasLower = false;

  late AnimationController _pageAnimController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final List<String> _gradeLevels = [
    'Grade 7', 'Grade 8', 'Grade 9', 'Grade 10',
    'Grade 11', 'Grade 12',
    '1st Year College', '2nd Year College', '3rd Year College', '4th Year College',
    'Graduate', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _pageAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _pageAnimController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _pageAnimController, curve: Curves.easeOut));
    _pageAnimController.forward();
  }

  @override
  void dispose() {
    _pageAnimController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _schoolController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _resendTimer?.cancel();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  // ── Navigation helpers ─────────────────────────────────────────────────────

  void _goToStep(int step) {
    _pageAnimController.reset();
    setState(() => _currentStep = step);
    _pageAnimController.forward();
  }

  void _nextStep() {
    if (_currentStep == 1) {
      _goToStep(2);
      return;
    }
    if (_currentStep == 2) {
      if (_formKeyStep2.currentState?.validate() ?? false) {
        FocusScope.of(context).unfocus();
        _goToStep(3);
      }
      return;
    }
    if (_currentStep == 3) {
      if (_formKeyStep3.currentState?.validate() ?? false) {
        if (!_agreedToPolicy) {
          _showError('Please accept the Terms of Service & Privacy Policy to continue.');
          return;
        }
        FocusScope.of(context).unfocus();
        _sendOTP();
      }
      return;
    }
  }

  void _previousStep() {
    FocusScope.of(context).unfocus();
    if (_currentStep > 1) _goToStep(_currentStep - 1);
  }

  // ── OTP Logic ──────────────────────────────────────────────────────────────

  Future<void> _sendOTP() async {
    setState(() => _isLoading = true);

    // Create the Firebase account first
    final int? age = int.tryParse(_ageController.text.trim());
    final String school = _schoolController.text.trim();

    final signUpError = await ref.read(currentUserProvider.notifier).signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
          age: age,
          school: school.isEmpty ? null : school,
          gradeLevel: _selectedGrade,
        );

    if (!mounted) return;

    if (signUpError != null) {
      setState(() => _isLoading = false);
      _showError(signUpError);
      return;
    }

    // Generate and email the 6-digit code
    final otpError = await ref
        .read(currentUserProvider.notifier)
        .sendOtpCode(email: _emailController.text.trim());

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (otpError != null) {
      _showError(otpError);
      return;
    }

    _clearOtpFields();
    _startResendTimer();
    _goToStep(4);
  }

  Future<void> _resendOTP() async {
    setState(() {
      _canResend = false;
      _resendSeconds = 30;
      _otpError = null;
    });
    _startResendTimer();
    _clearOtpFields();

    final error = await ref
        .read(currentUserProvider.notifier)
        .sendOtpCode(email: _emailController.text.trim());

    if (!mounted) return;

    if (error != null) {
      _showError(error);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('A new code has been sent to your email!'),
        backgroundColor: _kPrimary,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendSeconds > 0) {
          _resendSeconds--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  void _clearOtpFields() {
    for (final c in _otpControllers) {
      c.clear();
    }
  }

  String get _enteredOtp => _otpControllers.map((c) => c.text).join();

  void _onOtpDigitChanged(int index, String value) {
    setState(() => _otpError = null);
    if (value.isNotEmpty && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
    // Auto-submit once all 6 boxes are filled.
    if (_enteredOtp.length == 6 && !_isLoading) {
      FocusScope.of(context).unfocus();
      _verifyOtp();
    }
  }

  Future<void> _verifyOtp() async {
    final code = _enteredOtp;
    if (code.length != 6) {
      setState(() => _otpError = 'Please enter all 6 digits.');
      return;
    }

    setState(() {
      _isLoading = true;
      _otpError = null;
    });

    try {
      final isValid =
          await ref.read(currentUserProvider.notifier).verifyOtpCode(code);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (isValid) {
        _goToStep(5);
      } else {
        setState(() => _otpError = 'Incorrect code. Please try again.');
        _clearOtpFields();
        _otpFocusNodes[0].requestFocus();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _otpError = e.toString();
      });
      _clearOtpFields();
      _otpFocusNodes[0].requestFocus();
    }
  }

  // ── Password checks ───────────────────────────────────────────────────────

  void _onPasswordChanged(String value) {
    setState(() {
      _hasMinLength = value.length >= 8;
      _hasNumber = value.contains(RegExp(r'\d'));
      _hasUpper = value.contains(RegExp(r'[A-Z]'));
      _hasLower = value.contains(RegExp(r'[a-z]'));
    });
  }

  // ── Error helper ──────────────────────────────────────────────────────────

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // Decorative blobs
          Positioned(
            top: -50,
            right: -50,
            child: _Blob(size: 180, color: _kPrimary.withValues(alpha: 0.1)),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: _Blob(size: 220, color: _kPrimary.withValues(alpha: 0.07)),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(),

                // Content
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        child: WebResponsiveWrapper(
                          maxWidth: 580,
                          child: _buildCurrentStep(),
                        ),
                      ),
                    ),
                  ),
                ),

                // Footer
                if (_currentStep < 5) _buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        children: [
          // Back button + title row
          Row(
            children: [
              if (_currentStep > 1 && _currentStep < 5)
                GestureDetector(
                  onTap: _previousStep,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: _kTextDark),
                  ),
                )
              else
                const SizedBox(width: 36),
              const Expanded(
                child: Text(
                  'Create Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _kTextDark,
                  ),
                ),
              ),
              const SizedBox(width: 36),
            ],
          ),
          const SizedBox(height: 16),

          // Step dots
          if (_currentStep < 5) _buildStepIndicator(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    const totalDots = 4;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalDots * 2 - 1, (i) {
        if (i.isOdd) {
          // connector line
          final dotIndex = (i ~/ 2) + 1;
          final isCompleted = _currentStep > dotIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 32,
            height: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: isCompleted ? _kPrimary : Colors.grey.shade300,
            ),
          );
        } else {
          final dotStep = (i ~/ 2) + 1;
          final isActive = _currentStep >= dotStep;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isActive ? 14 : 10,
            height: isActive ? 14 : 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? _kPrimary : Colors.grey.shade300,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: _kPrimary.withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
          );
        }
      }),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Already have an account? ',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          GestureDetector(
            onTap: () => context.go('/login'),
            child: const Text(
              'Sign In',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _kPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step Router ───────────────────────────────────────────────────────────

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      case 3:
        return _buildStep3();
      case 4:
        return _buildStep4();
      case 5:
        return _buildStep5();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── STEP 1 — Welcome ──────────────────────────────────────────────────────

  Widget _buildStep1() {
    return Column(
      children: [
        const SizedBox(height: 24),
        // Hero image
        SizedBox(
          height: 200,
          child: Image.asset(
            'assets/images/register_hero.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          "Let's get started!",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: _kTextDark,
          ),
        ),
        const SizedBox(height: 12),
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(fontSize: 15, color: _kTextGrey, height: 1.5),
            children: [
              TextSpan(text: 'Create your account to start learning\nsmarter with '),
              TextSpan(
                text: 'Studieazy',
                style: TextStyle(
                  color: _kPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(text: '.'),
            ],
          ),
        ),
        const SizedBox(height: 48),
        _PrimaryButton(
          label: 'Next',
          icon: Icons.arrow_forward_rounded,
          onPressed: _nextStep,
        ),
        const SizedBox(height: 24),
        // Trust badges
        _buildTrustBadges(),
      ],
    );
  }

  Widget _buildTrustBadges() {
    final badges = [
      (Icons.security_rounded, 'Your Data is Safe'),
      (Icons.lock_outline_rounded, 'Privacy First'),
      (Icons.cloud_outlined, 'Study Anywhere'),
      (Icons.bolt_rounded, 'Learn Smarter'),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < badges.length; i += 2)
            Padding(
              padding: EdgeInsets.only(bottom: i + 2 < badges.length ? 16 : 0),
              child: Row(
                children: [
                  for (int j = i; j < (i + 2).clamp(0, badges.length); j++)
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _kPrimaryLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(badges[j].$1, color: _kPrimary, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              badges[j].$2,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _kTextDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── STEP 2 — Personal Information ─────────────────────────────────────────

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Personal Information',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _kTextDark),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tell us a bit about yourself!',
          style: TextStyle(fontSize: 14, color: _kTextGrey),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: _cardDecoration(),
          child: Form(
            key: _formKeyStep2,
            child: Column(
              children: [
                _buildField(
                  controller: _nameController,
                  label: 'Full Name',
                  hint: 'Enter your full name',
                  icon: Icons.person_outline_rounded,
                  maxLength: 60,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Full Name is required' : null,
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _ageController,
                  label: 'Age (Optional)',
                  hint: 'Enter your age',
                  icon: Icons.cake_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty) {
                      final age = int.tryParse(v);
                      if (age == null || age < 10 || age > 100) {
                        return 'Please enter a valid age (10–100)';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _schoolController,
                  label: 'School/Institution (Optional)',
                  hint: 'Enter your school or institution',
                  icon: Icons.school_outlined,
                  maxLength: 80,
                ),
                const SizedBox(height: 16),
                _buildDropdown(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _PrimaryButton(
          label: 'Next',
          icon: Icons.arrow_forward_rounded,
          onPressed: _nextStep,
        ),
      ],
    );
  }

  Widget _buildDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedGrade,
      style: const TextStyle(color: _kTextDark, fontSize: 14, fontWeight: FontWeight.w500),
      dropdownColor: Colors.white,
      decoration: _fieldDecoration('Grade/Year Level (Optional)', Icons.menu_book_outlined),
      items: _gradeLevels.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
      onChanged: (v) => setState(() => _selectedGrade = v),
    );
  }

  // ── STEP 3 — Account Details ───────────────────────────────────────────────

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Account Details',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _kTextDark),
        ),
        const SizedBox(height: 4),
        const Text(
          'Setup your account to continue',
          style: TextStyle(fontSize: 14, color: _kTextGrey),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: _cardDecoration(),
          child: Form(
            key: _formKeyStep3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Email
                const Text('Email',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextDark)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 14, color: _kTextDark, fontWeight: FontWeight.w500),
                  decoration: _fieldDecoration('Enter your email', Icons.email_outlined),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password
                const Text('Password',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextDark)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(fontSize: 14, color: _kTextDark, fontWeight: FontWeight.w500),
                  onChanged: _onPasswordChanged,
                  decoration: _fieldDecoration('Create a password', Icons.lock_outline_rounded)
                      .copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: _kTextGrey,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 8) return 'Password must be at least 8 characters';
                    if (!_hasNumber) return 'Password must contain a number';
                    if (!_hasUpper) return 'Password must contain an uppercase letter';
                    if (!_hasLower) return 'Password must contain a lowercase letter';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Password requirements
                _buildPasswordRequirements(),
                const SizedBox(height: 16),

                // Confirm Password
                const Text('Confirm Password',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextDark)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  style: const TextStyle(fontSize: 14, color: _kTextDark, fontWeight: FontWeight.w500),
                  decoration: _fieldDecoration('Confirm your password', Icons.lock_outline_rounded)
                      .copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: _kTextGrey,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please confirm your password';
                    if (v != _passwordController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Terms of Service & Privacy Policy Acceptance
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _agreedToPolicy
                        ? _kPrimary.withValues(alpha: 0.05)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _agreedToPolicy
                          ? _kPrimary.withValues(alpha: 0.3)
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _agreedToPolicy,
                          activeColor: _kPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          onChanged: (val) {
                            setState(() => _agreedToPolicy = val ?? false);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'I agree to the ',
                              style: TextStyle(
                                fontSize: 13,
                                color: _kTextDark,
                                height: 1.4,
                              ),
                            ),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () {
                                  LegalPolicyDialog.show(
                                    context,
                                    onAccept: () {
                                      setState(() => _agreedToPolicy = true);
                                    },
                                  );
                                },
                                child: const Text(
                                  'Terms of Service & Privacy Policy',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _kPrimary,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                    height: 1.4,
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
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _PrimaryButton(
          label: 'Send OTP',
          icon: Icons.send_rounded,
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _nextStep,
        ),
        const SizedBox(height: 12),
        _SecondaryButton(label: 'Back', onPressed: _previousStep),
      ],
    );
  }

  Widget _buildPasswordRequirements() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kPrimaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Password must contain:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kTextDark),
          ),
          const SizedBox(height: 8),
          _PasswordCheck(label: 'At least 8 characters', passed: _hasMinLength),
          _PasswordCheck(label: 'A number', passed: _hasNumber),
          _PasswordCheck(label: 'An uppercase letter', passed: _hasUpper),
          _PasswordCheck(label: 'A lowercase letter', passed: _hasLower),
        ],
      ),
    );
  }

  // ── STEP 4 — Enter OTP ───────────────────────────────────────────────────

  Widget _buildStep4() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: _kPrimaryLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_outlined, size: 44, color: _kPrimary),
        ),
        const SizedBox(height: 24),
        const Text(
          'Enter Verification Code',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _kTextDark),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a 6-digit code to',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _emailController.text.trim(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _kTextDark,
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _goToStep(3),
              child: const Text(
                'Edit',
                style: TextStyle(
                  fontSize: 13,
                  color: _kPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // 6-digit OTP boxes
        Container(
          padding: const EdgeInsets.all(24),
          decoration: _cardDecoration(),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) => _buildOtpBox(index)),
              ),
              if (_otpError != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 16, color: Colors.redAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _otpError!,
                        style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Verify button
        _PrimaryButton(
          label: 'Verify Code',
          icon: Icons.verified_outlined,
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _verifyOtp,
        ),
        const SizedBox(height: 16),

        // Resend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Didn't receive the code? ",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            GestureDetector(
              onTap: _canResend ? _resendOTP : null,
              child: Text(
                _canResend
                    ? 'Resend Code'
                    : 'Resend Code (${_resendSeconds}s)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _canResend ? _kPrimary : Colors.grey.shade400,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SecondaryButton(label: 'Back', onPressed: _previousStep),
      ],
    );
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 44,
      height: 52,
      child: TextField(
        controller: _otpControllers[index],
        focusNode: _otpFocusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: _kTextDark,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: const Color(0xFFF8F8FF),
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _otpError != null ? Colors.redAccent : Colors.grey.shade300,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: _otpError != null ? Colors.redAccent : Colors.grey.shade300,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kPrimary, width: 2),
          ),
        ),
        onChanged: (value) => _onOtpDigitChanged(index, value),
      ),
    );
  }

  // ── STEP 5 — Success ──────────────────────────────────────────────────────

  Widget _buildStep5() {
    return Column(
      children: [
        const SizedBox(height: 24),
        // Success illustration
        SizedBox(
          height: 180,
          child: Image.asset('assets/images/register_success.jpg', fit: BoxFit.contain),
        ),
        const SizedBox(height: 24),
        const Text(
          'Account Created!',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: _kTextDark),
        ),
        const SizedBox(height: 8),
        Text(
          'Your account has been created\nsuccessfully.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
        ),
        const SizedBox(height: 32),

        // What's Next card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "What's Next?",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kTextDark),
              ),
              const SizedBox(height: 16),
              _NextItem(
                icon: Icons.quiz_outlined,
                title: 'Create & study quizzes',
                subtitle: 'Make your own quizzes or explore shared ones.',
              ),
              const SizedBox(height: 12),
              _NextItem(
                icon: Icons.bar_chart_rounded,
                title: 'Track your progress',
                subtitle: 'Monitor your learning journey and improve.',
              ),
              const SizedBox(height: 12),
              _NextItem(
                icon: Icons.devices_rounded,
                title: 'Study anytime, anywhere',
                subtitle: 'Access your quizzes on any device, anytime.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Go to Home
        _PrimaryButton(
          label: 'Go to Home',
          icon: Icons.home_rounded,
          onPressed: () async {
            await ref.read(currentUserProvider.notifier).finalizeAfterVerification();
            if (mounted) context.go('/');
          },
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Shared UI helpers ─────────────────────────────────────────────────────

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: _kTextDark),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          decoration: _fieldDecoration(hint, icon),
          validator: validator,
          style: const TextStyle(
              fontSize: 14, color: _kTextDark, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _kTextGrey, fontSize: 14),
      prefixIcon: Icon(icon, color: _kPrimary, size: 20),
      filled: true,
      fillColor: const Color(0xFFF8F8FF),
      counterText: '',
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _kPrimary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

// ─── Shared Subwidgets ────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _PrimaryButton({
    required this.label,
    this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: _kPrimary.withValues(alpha: 0.4),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(icon, size: 18),
                  ],
                ],
              ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _SecondaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _kPrimary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          label,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: _kPrimary),
        ),
      ),
    );
  }
}

class _PasswordCheck extends StatelessWidget {
  final String label;
  final bool passed;

  const _PasswordCheck({required this.label, required this.passed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: passed ? Colors.green : Colors.grey.shade300,
            ),
            child: passed
                ? const Icon(Icons.check, color: Colors.white, size: 10)
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: passed ? Colors.green.shade700 : _kTextGrey,
              fontWeight: passed ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _NextItem({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _kPrimaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _kPrimary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold, color: _kTextDark)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}