import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Handles generation, delivery, and verification of email OTP codes.
/// Codes are hashed before storage — never stored in plaintext.
class OtpService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _emailJsServiceId = 'service_i3ek35b';
  static const _emailJsTemplateId = 'template_va0wg76';
  static const _emailJsPublicKey = '7-547Pitrocp66hMl';

  static const _otpTtl = Duration(minutes: 10);
  static const _maxAttempts = 5;

  String _generateCode() {
    final rand = Random.secure();
    return List.generate(6, (_) => rand.nextInt(10)).join();
  }

  String _hashCode(String code, String uid) {
    return sha256.convert(utf8.encode('$code:$uid')).toString();
  }

  /// Generates a code, stores its hash in Firestore, and emails it via EmailJS.
  Future<void> sendOtp({required String uid, required String email}) async {
    final code = _generateCode();
    final hashed = _hashCode(code, uid);
    final expiresAt = DateTime.now().add(_otpTtl);

    await _firestore.collection('otp_codes').doc(uid).set({
      'hashedCode': hashed,
      'email': email,
      'expiresAt': expiresAt.toIso8601String(),
      'attempts': 0,
      'createdAt': DateTime.now().toIso8601String(),
    });

    await _sendEmailWithRetry(email: email, code: code);
  }

  /// Sends email via EmailJS with automatic retry and progressive backoff (1-3s delays).
  /// This protects against concurrent request spikes, rate limits, and network blips.
  Future<void> _sendEmailWithRetry({
    required String email,
    required String code,
    int maxAttempts = 3,
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await http.post(
          Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'service_id': _emailJsServiceId,
            'template_id': _emailJsTemplateId,
            'user_id': _emailJsPublicKey,
            'template_params': {'to_email': email.trim(), 'otp_code': code},
          }),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          return; // Success!
        }

        // If rate-limited or server busy, delay 1s to 3s before retry
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: 1000 * attempt));
        } else {
          throw 'Failed to send verification email (${response.statusCode}). Please try again.';
        }
      } catch (e) {
        if (attempt >= maxAttempts) {
          if (e is String) rethrow;
          throw 'Failed to send verification email. Please check your internet connection and try again.';
        }
        await Future.delayed(Duration(milliseconds: 1000 * attempt));
      }
    }
  }

  /// Checks the entered code against the stored hash.
  /// Returns true if valid; throws a user-facing message otherwise.
  Future<bool> verifyOtp({required String uid, required String enteredCode}) async {
    final docRef = _firestore.collection('otp_codes').doc(uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      throw 'No verification code found. Please request a new one.';
    }

    final data = doc.data()!;
    final expiresAt = DateTime.parse(data['expiresAt'] as String);
    final attempts = (data['attempts'] as int?) ?? 0;

    if (DateTime.now().isAfter(expiresAt)) {
      throw 'This code has expired. Please request a new one.';
    }
    if (attempts >= _maxAttempts) {
      throw 'Too many incorrect attempts. Please request a new code.';
    }

    final hashedEntered = _hashCode(enteredCode, uid);
    if (hashedEntered != (data['hashedCode'] as String)) {
      await docRef.update({'attempts': attempts + 1});
      return false;
    }

    await docRef.delete();
    return true;
  }

  /// Generates OTP locally, saves hash to Firestore via Vercel Admin SDK,
  /// then sends the plain code to user via EmailJS directly from the app.
  Future<void> sendForgotPasswordOtp({required String email}) async {
    // 1. Generate code locally
    final code = _generateCode();

    // 2. Save hashed OTP to Firestore via Vercel Admin SDK (bypasses security rules)
    try {
      final saveUri = Uri.parse('https://vercelapi-blue.vercel.app/api/save-otp');
      final saveResponse = await http.post(
        saveUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'code': code}),
      );
      if (saveResponse.statusCode != 200) {
        final body = jsonDecode(saveResponse.body) as Map<String, dynamic>;
        throw body['error'] as String? ?? 'Failed to prepare verification code.';
      }
    } catch (e) {
      if (e is String) rethrow;
      throw 'Failed to prepare verification code. Please try again.';
    }

    // 3. Send OTP email via EmailJS with automatic retry & backoff
    await _sendEmailWithRetry(email: email, code: code);
  }

  /// Verifies the entered OTP for Forgot Password flow strictly via Vercel Admin API.
  Future<bool> verifyForgotPasswordOtp({required String email, required String enteredCode}) async {
    try {
      final uri = Uri.parse('https://vercelapi-blue.vercel.app/api/verify-otp');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'otp': enteredCode.trim(),
        }),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['valid'] == true) {
        return true;
      }
      final errorMsg = body['error'] as String? ?? 'Incorrect OTP code. Please try again.';
      throw errorMsg;
    } on FormatException {
      throw 'Invalid response from server. Please try again.';
    } catch (e) {
      if (e is String) rethrow;
      throw e.toString().replaceAll('Exception: ', '');
    }
  }
}