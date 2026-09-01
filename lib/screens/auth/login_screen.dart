import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/sweet_alert_dialog.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _showResultModal(
    String title,
    String message,
    bool isSuccess, {
    VoidCallback? onDismiss,
  }) async {
    if (isSuccess) {
      await SweetAlert.showSuccess(
        context,
        title: title,
        subtitle: message,
      );
    } else {
      await SweetAlert.showError(
        context,
        title: title,
        subtitle: message,
      );
    }
    if (onDismiss != null) onDismiss();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final error = await ref
          .read(currentUserProvider.notifier)
          .signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (error != null) {
        _showResultModal(
          'Login Failed',
          error.replaceAll('Exception: ', ''),
          false,
        );
      } else {
        _showResultModal(
          'Welcome Back!',
          'You have successfully logged in.',
          true,
          onDismiss: () {
            if (mounted) context.go('/');
          },
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showResultModal(
        'Error',
        'Something went wrong. Please try again.',
        false,
      );
    }
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    final List<TextEditingController> otpCtrls = List.generate(6, (_) => TextEditingController());
    final List<FocusNode> otpFocusNodes = List.generate(6, (_) => FocusNode());
    
    int step = 1; // 1: Email, 2: OTP, 3: New Password, 4: Success
    bool isLoading = false;
    bool obscureNewPassword = true;
    bool obscureConfirmPassword = true;
    String? errorMessage;
    String verifiedOtpCode = '';
    int resendSeconds = 30;
    bool canResend = false;
    Timer? resendTimer;
    const primaryColor = Color(0xFF5C4EE8);

    void startTimer(void Function(void Function()) setDialogState) {
      resendTimer?.cancel();
      resendSeconds = 30;
      canResend = false;
      resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setDialogState(() {
          if (resendSeconds > 0) {
            resendSeconds--;
          } else {
            canResend = true;
            timer.cancel();
          }
        });
      });
    }

    showDialog(
      context: context,
      barrierDismissible: !isLoading,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final dialogBg = isDark ? const Color(0xFF1F2937) : Colors.white;
            final titleColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
            final bodyColor = isDark ? Colors.grey.shade300 : Colors.grey.shade600;
            final inputBg = isDark ? const Color(0xFF111827) : const Color(0xFFF8F8FF);
            final inputBorder = isDark ? const Color(0xFF374151) : Colors.grey.shade300;

            return PopScope(
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) {
                  resendTimer?.cancel();
                }
              },
              child: Center(
                child: Dialog(
                  backgroundColor: dialogBg,
                  elevation: 16,
                  insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Icon & Title
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                step == 4
                                    ? Icons.check_circle_outline_rounded
                                    : (step == 3
                                        ? Icons.lock_open_rounded
                                        : (step == 2 ? Icons.pin_outlined : Icons.lock_reset_rounded)),
                                color: primaryColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    step == 1
                                        ? 'Forgot Password'
                                        : (step == 2
                                            ? 'Verify OTP Code'
                                            : (step == 3 ? 'Create New Password' : 'Password Reset')),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: titleColor,
                                    ),
                                  ),
                                  Text(
                                    step == 1
                                        ? 'Step 1 of 3  ·  Enter Email'
                                        : (step == 2
                                            ? 'Step 2 of 3  ·  Verify 6-Digit Code'
                                            : (step == 3 ? 'Step 3 of 3  ·  Set New Password' : 'Reset Complete')),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        if (errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50.withValues(alpha: isDark ? 0.2 : 1.0),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade200.withValues(alpha: isDark ? 0.3 : 1.0)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, size: 18, color: isDark ? Colors.red.shade300 : Colors.red.shade600),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    errorMessage!,
                                    style: TextStyle(fontSize: 12, color: isDark ? Colors.red.shade200 : Colors.red.shade700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // STEP 1: Enter Email
                        if (step == 1) ...[
                          Text(
                            'Enter your registered email address. We will send a 6-digit OTP code to verify your account.',
                            style: TextStyle(
                              fontSize: 13,
                              color: bodyColor,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(color: titleColor, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Enter your email',
                              hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400, fontSize: 14),
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                color: primaryColor,
                                size: 20,
                              ),
                              filled: true,
                              fillColor: inputBg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: inputBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: inputBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: primaryColor, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.grey.shade300),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: isLoading
                                      ? null
                                      : () async {
                                          final email = emailCtrl.text.trim();
                                          if (email.isEmpty || !email.contains('@')) {
                                            setDialogState(() {
                                              errorMessage = 'Please enter a valid email address.';
                                            });
                                            return;
                                          }
                                          setDialogState(() {
                                            isLoading = true;
                                            errorMessage = null;
                                          });

                                          final error = await ref
                                              .read(currentUserProvider.notifier)
                                              .sendForgotPasswordOtpCode(email: email);

                                          if (!ctx.mounted) return;
                                          if (error != null) {
                                            setDialogState(() {
                                              isLoading = false;
                                              errorMessage = error.replaceAll('Exception: ', '');
                                            });
                                          } else {
                                            startTimer(setDialogState);
                                            setDialogState(() {
                                              isLoading = false;
                                              step = 2;
                                            });
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: isLoading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Send OTP',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        // STEP 2: Enter OTP Code
                        if (step == 2) ...[
                          Text(
                            'We sent a 6-digit code to ${emailCtrl.text.trim()}. Enter it below to verify.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          // 6-digit OTP fields
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(6, (index) {
                              return SizedBox(
                                width: 42,
                                height: 52,
                                child: TextFormField(
                                  controller: otpCtrls[index],
                                  focusNode: otpFocusNodes[index],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  maxLength: 1,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A2E),
                                  ),
                                  decoration: InputDecoration(
                                    counterText: '',
                                    filled: true,
                                    fillColor: const Color(0xFFF8F8FF),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: primaryColor, width: 2),
                                    ),
                                  ),
                                  onChanged: (value) async {
                                    setDialogState(() => errorMessage = null);
                                    if (value.isNotEmpty && index < 5) {
                                      otpFocusNodes[index + 1].requestFocus();
                                    }
                                    if (value.isEmpty && index > 0) {
                                      otpFocusNodes[index - 1].requestFocus();
                                    }
                                    final enteredCode = otpCtrls.map((c) => c.text).join();
                                    if (enteredCode.length == 6 && !isLoading) {
                                      setDialogState(() => isLoading = true);
                                      try {
                                        final isValid = await ref
                                            .read(currentUserProvider.notifier)
                                            .verifyForgotPasswordOtpCode(
                                              email: emailCtrl.text.trim(),
                                              code: enteredCode,
                                            );
                                        if (!ctx.mounted) return;
                                        if (isValid) {
                                          verifiedOtpCode = enteredCode;
                                          resendTimer?.cancel();
                                          setDialogState(() {
                                            isLoading = false;
                                            step = 3; // Advance to Enter New Password page inside app!
                                          });
                                        } else {
                                          setDialogState(() {
                                            isLoading = false;
                                            errorMessage = 'Incorrect OTP code. Please try again.';
                                          });
                                          for (final c in otpCtrls) {
                                            c.clear();
                                          }
                                          otpFocusNodes[0].requestFocus();
                                        }
                                      } catch (e) {
                                        if (!ctx.mounted) return;
                                        setDialogState(() {
                                          isLoading = false;
                                          errorMessage = e.toString().replaceAll('Exception: ', '');
                                        });
                                      }
                                    }
                                  },
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 16),
                          // Resend timer
                          Center(
                            child: canResend
                                ? TextButton.icon(
                                    onPressed: isLoading
                                        ? null
                                        : () async {
                                            setDialogState(() {
                                              isLoading = true;
                                              errorMessage = null;
                                              for (final c in otpCtrls) {
                                                c.clear();
                                              }
                                            });
                                            final error = await ref
                                                .read(currentUserProvider.notifier)
                                                .sendForgotPasswordOtpCode(email: emailCtrl.text.trim());
                                            if (!ctx.mounted) return;
                                            if (error != null) {
                                              setDialogState(() {
                                                isLoading = false;
                                                errorMessage = error.replaceAll('Exception: ', '');
                                              });
                                            } else {
                                              startTimer(setDialogState);
                                              setDialogState(() {
                                                isLoading = false;
                                              });
                                              ScaffoldMessenger.of(ctx).showSnackBar(
                                                const SnackBar(
                                                  content: Text('A new OTP code has been sent!'),
                                                  backgroundColor: primaryColor,
                                                ),
                                              );
                                            }
                                          },
                                    icon: const Icon(Icons.refresh, size: 16, color: primaryColor),
                                    label: const Text(
                                      'Resend Code',
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  )
                                : Text(
                                    'Resend code in ${resendSeconds}s',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                  ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isLoading
                                      ? null
                                      : () {
                                          resendTimer?.cancel();
                                          setDialogState(() {
                                            errorMessage = null;
                                            step = 1;
                                          });
                                        },
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.grey.shade300),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text(
                                    'Back',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        // STEP 3: Enter New Password
                        if (step == 3) ...[
                          Text(
                            'OTP verified! Enter your new password below for ${emailCtrl.text.trim()}.',
                            style: TextStyle(
                              fontSize: 13,
                              color: bodyColor,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: newPasswordCtrl,
                            obscureText: obscureNewPassword,
                            style: TextStyle(color: titleColor, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Enter new password',
                              hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400, fontSize: 14),
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                                color: primaryColor,
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscureNewPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: Colors.grey.shade400,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setDialogState(() {
                                    obscureNewPassword = !obscureNewPassword;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: inputBg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: inputBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: inputBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: primaryColor, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: confirmPasswordCtrl,
                            obscureText: obscureConfirmPassword,
                            style: TextStyle(color: titleColor, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Confirm new password',
                              hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400, fontSize: 14),
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                                color: primaryColor,
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: Colors.grey.shade400,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setDialogState(() {
                                    obscureConfirmPassword = !obscureConfirmPassword;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: inputBg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: inputBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: inputBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: primaryColor, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Live password security checklist chips
                          Builder(builder: (context) {
                            final p = newPasswordCtrl.text;
                            final hasMinLength = p.length >= 8;
                            final hasNumber = p.contains(RegExp(r'\d'));
                            final hasUpper = p.contains(RegExp(r'[A-Z]'));
                            final hasLower = p.contains(RegExp(r'[a-z]'));

                            Widget reqItem(String label, bool met) {
                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                    size: 14,
                                    color: met ? Colors.green : Colors.grey.shade400,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: met ? Colors.green.shade700 : Colors.grey.shade600,
                                      fontWeight: met ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              );
                            }

                            return Wrap(
                              spacing: 12,
                              runSpacing: 6,
                              children: [
                                reqItem('8+ characters', hasMinLength),
                                reqItem('1+ number', hasNumber),
                                reqItem('Uppercase', hasUpper),
                                reqItem('Lowercase', hasLower),
                              ],
                            );
                          }),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isLoading
                                      ? null
                                      : () {
                                          setDialogState(() {
                                            errorMessage = null;
                                            step = 2;
                                          });
                                        },
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: Colors.grey.shade300),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text(
                                    'Back',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: isLoading
                                      ? null
                                      : () async {
                                          final pass = newPasswordCtrl.text;
                                          final confirmPass = confirmPasswordCtrl.text;

                                          final hasMinLength = pass.length >= 8;
                                          final hasNumber = pass.contains(RegExp(r'\d'));
                                          final hasUpper = pass.contains(RegExp(r'[A-Z]'));
                                          final hasLower = pass.contains(RegExp(r'[a-z]'));

                                          if (!hasMinLength) {
                                            setDialogState(() {
                                              errorMessage = 'Password must be at least 8 characters long.';
                                            });
                                            return;
                                          }
                                          if (!hasNumber) {
                                            setDialogState(() {
                                              errorMessage = 'Password must contain at least one number.';
                                            });
                                            return;
                                          }
                                          if (!hasUpper || !hasLower) {
                                            setDialogState(() {
                                              errorMessage = 'Password must contain both uppercase and lowercase letters.';
                                            });
                                            return;
                                          }
                                          if (pass != confirmPass) {
                                            setDialogState(() {
                                              errorMessage = 'Passwords do not match.';
                                            });
                                            return;
                                          }

                                          setDialogState(() {
                                            isLoading = true;
                                            errorMessage = null;
                                          });

                                          // Reset password via Vercel Admin API
                                          final error = await ref
                                              .read(currentUserProvider.notifier)
                                              .resetPasswordViaVercel(
                                                email: emailCtrl.text.trim(),
                                                otp: verifiedOtpCode,
                                                newPassword: pass,
                                              );

                                          if (!ctx.mounted) return;
                                          if (error != null) {
                                            setDialogState(() {
                                              isLoading = false;
                                              errorMessage = error;
                                            });
                                          } else {
                                            setDialogState(() {
                                              isLoading = false;
                                              step = 4; // Advance to Success screen!
                                            });
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: isLoading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Change Password',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        // STEP 4: Success Screen
                        if (step == 4) ...[
                          Center(
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_circle_rounded,
                                color: Colors.green.shade600,
                                size: 48,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Password Changed Successfully!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your password has been updated in Firebase. You can now log in using your new password.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                resendTimer?.cancel();
                                Navigator.pop(ctx);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Back to Login',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  },
);
}

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    const primaryColor = Color(0xFF5C4EE8);
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF0EFFF);
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subColor = isDark ? Colors.grey.shade400 : const Color(0xFF6B7280);
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);

    if (isDesktop) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF020617) : const Color(0xFF0F1223),
        body: Row(
          children: [
            // Left Column: Branding & Hero Panel
            Expanded(
              flex: 55,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFF1E1B4B)],
                  ),
                ),
                padding: const EdgeInsets.all(56),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset('assets/images/Logo.png', fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Studieazy',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    const Text(
                      'Master Any Subject\nWith AI Flashcards',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Transform text, documents, and notes into interactive quiz sets powered by Google Gemini AI.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/web_hero_banner.jpg',
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const SizedBox(),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildFeatureItem(Icons.auto_awesome_rounded, 'Generate Quizzes instantly with AI'),
                    const SizedBox(height: 12),
                    _buildFeatureItem(Icons.repeat_rounded, 'Spaced repetition flashcards for faster recall'),
                    const SizedBox(height: 12),
                    _buildFeatureItem(Icons.cloud_done_rounded, 'Seamless Web & Mobile sync'),
                  ],
                ),
              ),
            ),
            // Right Column: Form Container
            Expanded(
              flex: 45,
              child: Container(
                color: bgColor,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(48),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Studi',
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                          color: titleColor,
                                        ),
                                      ),
                                      const TextSpan(
                                        text: 'eazy',
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Sign in to your account',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: subColor,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                _buildFormCard(context, primaryColor),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Decorative blobs ───────────────────────────────────────
          Positioned(
            top: -60,
            right: -60,
            child: _Blob(
              size: 200,
              color: primaryColor.withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            top: 60,
            right: 20,
            child: _DotGrid(color: primaryColor.withValues(alpha: 0.18)),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: _Blob(
              size: 240,
              color: primaryColor.withValues(alpha: 0.08),
            ),
          ),

          // ── Main content ───────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: 24,
                vertical: size.height * 0.02,
              ),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Logo
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.25),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            'assets/images/Logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Title
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Studi',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: titleColor,
                                ),
                              ),
                              const TextSpan(
                                text: 'eazy',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'LEARN  •  GROW  •  EXPLORE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Welcome text
                        Text(
                          'Welcome! 👋',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sign in to continue your learning journey',
                          style: TextStyle(
                            fontSize: 14,
                            color: subColor,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Glass Card ──────────────────────────────
                        _buildFormCard(context, primaryColor),
                        const SizedBox(height: 28),

                        // ── Feature Row ─────────────────────────────
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _FeatureTile(
                              icon: Icons.style_rounded,
                              iconBg: Color(0xFF7C6FF7),
                              label: 'Smart Flashcards',
                              sub: 'Flip & memorize faster',
                            ),
                            _FeatureTile(
                              icon: Icons.auto_awesome_rounded,
                              iconBg: Color(0xFFFF8C42),
                              label: 'AI Quiz Generator',
                              sub: 'Upload docs & generate',
                            ),
                            _FeatureTile(
                              icon: Icons.quiz_rounded,
                              iconBg: Color(0xFF4CAF50),
                              label: 'Quiz Modes',
                              sub: 'MCQ, ID & Enumeration',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard(BuildContext context, Color primaryColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final labelColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8F8FF);
    final inputBorder = isDark ? const Color(0xFF334155) : Colors.grey.shade300;
    final hintColor = isDark ? Colors.grey.shade500 : Colors.grey.shade400;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Email',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: labelColor, fontSize: 14),
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: 'Enter your email',
                hintStyle: TextStyle(
                  color: hintColor,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.email_outlined,
                  color: primaryColor,
                  size: 20,
                ),
                filled: true,
                fillColor: inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: inputBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Password',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: TextStyle(color: labelColor, fontSize: 14),
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _isLoading ? null : _login(),
              decoration: InputDecoration(
                hintText: 'Enter your password',
                hintStyle: TextStyle(
                  color: hintColor,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.lock_outline,
                  color: primaryColor,
                  size: 20,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.grey.shade500,
                    size: 20,
                  ),
                  onPressed: () => setState(
                    () => _obscurePassword = !_obscurePassword,
                  ),
                ),
                filled: true,
                fillColor: inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: inputBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _rememberMe,
                        onChanged: (val) => setState(() => _rememberMe = val ?? false),
                        activeColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Remember me',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade300 : const Color(0xFF4B5563),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _showForgotPasswordDialog,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Forgot password?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/register'),
                    style: TextButton.styleFrom(
                      foregroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
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
}

// ── Helper Widgets ─────────────────────────────────────────────────────────────

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

class _DotGrid extends StatelessWidget {
  final Color color;
  const _DotGrid({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
        ),
        itemCount: 25,
        itemBuilder:
            (context, index) => Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String label;
  final String sub;

  const _FeatureTile({
    required this.icon,
    required this.iconBg,
    required this.label,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: iconBg.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          sub,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

