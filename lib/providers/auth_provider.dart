import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/local_user_store.dart';
import '../services/otp_service.dart';
import '../models/user_model.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final localUserStoreProvider = Provider<LocalUserStore>(
  (ref) => LocalUserStore(),
);
final otpServiceProvider = Provider<OtpService>((ref) => OtpService());

/// Exposes [UserModel?] as an [AsyncValue] so the UI can distinguish between:
///   - [AsyncLoading]      → Firebase Auth not yet resolved
///   - [AsyncData(null)]   → definitely signed out
///   - [AsyncData(user)]   → authenticated, user data ready
final currentUserProvider =
    AsyncNotifierProvider<AuthNotifier, UserModel?>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<UserModel?> {
  AuthService get _authService => ref.read(authServiceProvider);
  LocalUserStore get _localUserStore => ref.read(localUserStoreProvider);
  OtpService get _otpService => ref.read(otpServiceProvider);

  @override
  Future<UserModel?> build() async {
    // Subscribe to auth state FIRST — before any await — so we never miss events.
    late final StreamSubscription<dynamic> sub;
    final completer = Completer<UserModel?>();

    sub = _authService.authStateChanges.listen((fbUser) async {
      if (!completer.isCompleted) {
        final user = await _resolveAuthUser(fbUser);
        completer.complete(user);
      } else {
        // Subsequent auth events (explicit sign-out, token refresh, a fresh
        // sign-up, etc.)
        if (fbUser == null) {
          // Ignore transient nulls — only sign out when local session was cleared.
          final stillHasSession = await _localUserStore.hasActiveSession();
          if (!stillHasSession) {
            state = const AsyncData(null);
          }
        } else {
          final user = await _restoreUser(fbUser);
          if (user != null && user.otpVerified) {
            state = AsyncData(user);
          }
          // If otpVerified is false, this is a freshly created account
          // still mid-registration (Firebase signs the account in
          // immediately on creation, but we don't treat the app as
          // "logged in" until the user finishes the OTP step). Do
          // nothing here — finalizeAfterVerification() handles it.
        }
      }
    });

    ref.onDispose(sub.cancel);

    // Restore the last signed-in account immediately on cold start so the app
    // opens on home after closing, swiping from recents, or rebooting the phone.
    final cachedSession = await _localUserStore.readActiveUser();
    if (cachedSession != null && !completer.isCompleted) {
      state = AsyncData(cachedSession);
    }

    final fbUser = _authService.currentFirebaseUser;
    if (fbUser != null) {
      final cached = await _localUserStore.read(fbUser.uid);
      if (cached != null && !completer.isCompleted) {
        state = AsyncData(cached);
      }
    }

    return completer.future;
  }

  /// Resolves auth on startup. Firebase may briefly report no user while it
  /// reads the persisted session from disk — fall back to the local session
  /// marker so users are not sent to login unless they explicitly signed out.
  ///
  /// Also guards against cold-starting straight into an account that was
  /// created but never finished OTP verification (e.g. user closed the app
  /// mid-registration). The local cache is only ever populated for accounts
  /// that completed verification, so it's a safe fallback here.
  Future<UserModel?> _resolveAuthUser(dynamic fbUser) async {
    if (fbUser != null) {
      final user = await _restoreUser(fbUser);
      if (user != null && user.otpVerified) {
        return user;
      }
      return _localUserStore.readActiveUser();
    }

    return _localUserStore.readActiveUser();
  }

  /// Restores a [UserModel] for [fbUser]:
  ///   1. Check local SharedPreferences cache first (works offline).
  ///   2. Try Firestore for fresh data (works online).
  ///   3. Fall back to building a minimal model from Firebase Auth data
  ///      so the user is NEVER kicked to login just because they are offline.
  Future<UserModel?> _restoreUser(dynamic fbUser) async {
    if (fbUser.isAnonymous == true) return null;
    final uid = fbUser.uid as String;

    // Step 1: local cache
    final cachedUser = await _localUserStore.read(uid);
    if (cachedUser != null && cachedUser.otpVerified) {
      // Show cached immediately, then try to refresh from Firestore.
      state = AsyncData(cachedUser);
    }

    // Step 2: Firestore (best-effort, may fail offline)
    try {
      final remoteUser = await _authService.getUserFromFirestore(uid);
      if (remoteUser != null) {
        if (remoteUser.otpVerified) await _localUserStore.save(remoteUser);
        return remoteUser;
      }
    } catch (_) {
      // Offline or network error — fall through to cached / minimal model.
    }

    if (cachedUser != null) return cachedUser;

    // Step 3: Firebase Auth has a valid session but we have no cached profile
    // (e.g. first launch after clearing app data, still offline).
    // Build a minimal UserModel from Firebase Auth metadata so the user
    // stays logged in and can use cached quiz data.
    final email = (fbUser.email as String?) ?? '';
    final displayName = (fbUser.displayName as String?) ?? email.split('@').first;
    final minimal = UserModel(
      id: uid,
      email: email,
      name: displayName.isEmpty ? 'Student' : displayName,
      createdAt: DateTime.now(),
      // Unknown offline — treat as verified rather than locking an
      // established offline user out; Firestore will correct this once
      // back online.
      otpVerified: true,
    );
    // Do NOT save this minimal model — it will be overwritten by Firestore
    // the next time the user goes online.
    return minimal;
  }

  // ── Auth actions ─────────────────────────────────────────────────────────────

  Future<String?> signUp({
    required String email,
    required String password,
    required String name,
    int? age,
    String? school,
    String? gradeLevel,
  }) async {
    try {
      final user = await _authService.signUp(
        email: email,
        password: password,
        name: name,
        age: age,
        school: school,
        gradeLevel: gradeLevel,
      );
      if (user == null) return 'Authentication failed. Please try again.';
      // Don't set app state here — the account still needs OTP
      // verification. Setting it now would let the router send the user
      // straight to home before they ever see the OTP entry step.
      return null;
    } catch (e) {
      final message = e.toString();

      // If the account already exists, this is most likely the same
      // person retrying after their first OTP email failed to send
      // (Firebase already created the account on the first attempt,
      // even though the email step failed afterwards). Try resuming
      // that in-progress registration instead of hard-failing.
      if (message.contains('already exists')) {
        try {
          final existingUser = await _authService.signIn(
            email: email,
            password: password,
          );
          if (existingUser != null && !existingUser.otpVerified) {
            // Same unfinished registration — don't set app state, just
            // let the caller proceed to (re)send the OTP.
            return null;
          }
          if (existingUser != null && existingUser.otpVerified) {
            return 'An account with this email already exists. Please sign in instead.';
          }
        } catch (_) {
          // Wrong password, or some other issue — fall through to the
          // original error below.
        }
      }

      return message;
    }
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _authService.signIn(email: email, password: password);
      if (user == null) return 'Authentication failed. Please try again.';
      final userWithActivity = user.copyWith(lastActiveAt: DateTime.now());
      state = AsyncData(userWithActivity);
      await _localUserStore.save(userWithActivity);
      // Update lastActiveAt in Firestore (best-effort, won't block login)
      _authService.updateLastActive(user.id);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> signOut() async {
    final userId =
        state.valueOrNull?.id ?? _authService.currentFirebaseUser?.uid;
    // Clear local session first so auth stream null events cannot resurrect it.
    if (userId != null) await _localUserStore.clear(userId);
    await _authService.signOut();
    state = const AsyncData(null);
  }

  /// Generates and emails a 6-digit OTP code to [email] for the currently
  /// signed-up (but not-yet-verified) Firebase user.
  Future<String?> sendOtpCode({required String email}) async {
    final uid = _authService.currentFirebaseUser?.uid;
    if (uid == null) return 'No account found. Please try registering again.';
    try {
      await _otpService.sendOtp(uid: uid, email: email);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Checks [code] against the OTP stored for the currently signed-up user.
  /// Returns true if correct, false if incorrect. Throws a user-facing
  /// message string if the code is expired, missing, or attempts are used up.
  Future<bool> verifyOtpCode(String code) async {
    final uid = _authService.currentFirebaseUser?.uid;
    if (uid == null) throw 'No account found. Please try registering again.';
    final isValid = await _otpService.verifyOtp(uid: uid, enteredCode: code);
    if (isValid) {
      await _authService.markOtpVerified(uid);
    }
    return isValid;
  }

  /// Marks the user as fully signed in. Call this only after
  /// [verifyOtpCode] has returned true — i.e. once the user has actually
  /// entered the correct code during registration.
  Future<void> finalizeAfterVerification() async {
    final fbUser = _authService.currentFirebaseUser;
    if (fbUser == null) return;
    final user = await _restoreUser(fbUser);
    if (user != null) {
      state = AsyncData(user);
      await _localUserStore.save(user);
    }
  }

  /// Sends a Firebase password reset email to [email].
  Future<String?> sendPasswordReset(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Generates and emails a 6-digit OTP code to [email] for Forgot Password flow.
  Future<String?> sendForgotPasswordOtpCode({required String email}) async {
    try {
      final exists = await _authService.checkEmailExists(email);
      if (!exists) {
        return 'No user found with this email.';
      }
      await _otpService.sendForgotPasswordOtp(email: email);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Verifies [code] for Forgot Password flow and marks OTP as verified in Firestore.
  Future<bool> verifyForgotPasswordOtpCode({
    required String email,
    required String code,
  }) async {
    final isValid = await _otpService.verifyForgotPasswordOtp(
      email: email,
      enteredCode: code,
    );
    return isValid;
  }

  /// Calls our Vercel serverless API to update the Firebase Auth password.
  /// The API validates the OTP hash in Firestore using Firebase Admin SDK.
  Future<String?> resetPasswordViaVercel({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final uri = Uri.parse(
          'https://vercelapi-blue.vercel.app/api/reset-password');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'otp': otp,
          'newPassword': newPassword,
        }),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        return null; // success
      }
      return (body['error'] as String?) ?? 'Something went wrong.';
    } catch (e) {
      return 'Network error. Please check your connection.';
    }
  }

  /// Completes password reset in Firebase Auth with the action code (or link) and new password.
  Future<String?> confirmPasswordReset({
    required String codeOrLink,
    required String newPassword,
  }) async {
    try {
      final code = _extractOobCode(codeOrLink);
      await _authService.confirmPasswordReset(code: code, newPassword: newPassword);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  String _extractOobCode(String input) {
    final trimmed = input.trim();
    if (trimmed.contains('oobCode=')) {
      try {
        final uri = Uri.parse(trimmed);
        return uri.queryParameters['oobCode'] ?? trimmed;
      } catch (_) {
        return trimmed;
      }
    }
    return trimmed;
  }

  Future<String?> updateProfile({
    String? name,
    int? age,
    String? address,
    String? bio,
    Uint8List? profileImageBytes,
  }) async {
    final currentUser = state.valueOrNull;
    if (currentUser == null) return 'No user logged in';
    try {
      final user = await _authService.updateProfile(
        userId: currentUser.id,
        name: name,
        age: age,
        address: address,
        bio: bio,
        profileImageBytes: profileImageBytes,
      );
      final updatedUser = user ??
          currentUser.copyWith(
            name: name ?? currentUser.name,
            age: age ?? currentUser.age,
            address: address ?? currentUser.address,
            bio: bio ?? currentUser.bio,
            profileImageBase64: profileImageBytes != null
                ? base64Encode(profileImageBytes)
                : currentUser.profileImageBase64,
          );
      state = AsyncData(updatedUser);
      await _localUserStore.save(updatedUser);
      return null;
    } catch (e) {
      // Fallback: save profile changes locally so user experience is smooth
      final fallbackUser = currentUser.copyWith(
        name: name ?? currentUser.name,
        age: age ?? currentUser.age,
        address: address ?? currentUser.address,
        bio: bio ?? currentUser.bio,
        profileImageBase64: profileImageBytes != null
            ? base64Encode(profileImageBytes)
            : currentUser.profileImageBase64,
      );
      state = AsyncData(fallbackUser);
      await _localUserStore.save(fallbackUser);
      return null;
    }
  }

  /// Writes streak data directly to Firestore (called by [StreakNotifier]).
  Future<void> updateStreakInFirestore({
    required String userId,
    required int streakCount,
    required String lastStreakDate,
  }) async {
    await _authService.updateStreak(
      userId: userId,
      streakCount: streakCount,
      lastStreakDate: lastStreakDate,
    );
    // Also update local state.
    final current = state.valueOrNull;
    if (current != null) {
      final updated = current.copyWith(
        streakCount: streakCount,
        lastStreakDate: lastStreakDate,
        pendingStreakSync: false,
      );
      state = AsyncData(updated);
      await _localUserStore.save(updated);
    }
  }

  Future<String?> clearAllData() async {
    final currentUser = state.valueOrNull;
    if (currentUser == null) return 'No user logged in';
    try {
      await _authService.deleteAllUserData(currentUser.id);
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}