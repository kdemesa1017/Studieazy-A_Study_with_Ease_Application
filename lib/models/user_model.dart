class UserModel {
  final String id;
  final String email;
  final String name;
  final String? profileImageUrl;

  /// Base64-encoded, size-limited avatar stored with the profile in Firestore.
  final String? profileImageBase64;
  final int? age;
  final String? address;
  final String? bio;

  /// School or institution the user attends.
  final String? school;

  /// Grade level or year (e.g., "Grade 11", "3rd Year College").
  final String? gradeLevel;

  final DateTime createdAt;
  final DateTime? lastSyncedAt;

  /// True once the user has entered the correct 6-digit OTP sent to their
  /// email during registration. Accounts are not considered fully
  /// authenticated in the app until this is true.
  final bool otpVerified;

  // ── Streak fields ────────────────────────────────────────────────────────────

  /// Consecutive days the user has opened the app.
  final int streakCount;

  /// ISO-8601 date string of the last day the streak was incremented
  /// (e.g., "2026-07-26"). Only the date part matters.
  final String? lastStreakDate;

  /// True when the streak was incremented offline and hasn't been synced
  /// to Firestore yet.
  final bool pendingStreakSync;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.profileImageUrl,
    this.profileImageBase64,
    this.age,
    this.address,
    this.bio,
    this.school,
    this.gradeLevel,
    required this.createdAt,
    this.lastSyncedAt,
    this.otpVerified = false,
    this.streakCount = 0,
    this.lastStreakDate,
    this.pendingStreakSync = false,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'profileImageUrl': profileImageUrl,
      'profileImageBase64': profileImageBase64,
      'age': age,
      'address': address,
      'bio': bio,
      'school': school,
      'gradeLevel': gradeLevel,
      'createdAt': createdAt.toIso8601String(),
      'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      'otpVerified': otpVerified,
      'streakCount': streakCount,
      'lastStreakDate': lastStreakDate,
      // pendingStreakSync is local-only; never written to Firestore
    };
  }

  factory UserModel.fromFirestore(Map<String, dynamic> data) {
    return UserModel(
      id: data['id'] as String,
      email: data['email'] as String,
      name: data['name'] as String,
      profileImageUrl: data['profileImageUrl'] as String?,
      profileImageBase64: data['profileImageBase64'] as String?,
      age: data['age'] as int?,
      address: data['address'] as String?,
      bio: data['bio'] as String?,
      school: data['school'] as String?,
      gradeLevel: data['gradeLevel'] as String?,
      createdAt: DateTime.parse(data['createdAt'] as String),
      lastSyncedAt:
          data['lastSyncedAt'] != null
              ? DateTime.parse(data['lastSyncedAt'] as String)
              : null,
      otpVerified: (data['otpVerified'] as bool?) ?? false,
      streakCount: (data['streakCount'] as int?) ?? 0,
      lastStreakDate: data['lastStreakDate'] as String?,
      pendingStreakSync: false,
    );
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? profileImageUrl,
    String? profileImageBase64,
    int? age,
    String? address,
    String? bio,
    String? school,
    String? gradeLevel,
    DateTime? createdAt,
    DateTime? lastSyncedAt,
    bool? otpVerified,
    int? streakCount,
    String? lastStreakDate,
    bool? pendingStreakSync,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
      age: age ?? this.age,
      address: address ?? this.address,
      bio: bio ?? this.bio,
      school: school ?? this.school,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      createdAt: createdAt ?? this.createdAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      otpVerified: otpVerified ?? this.otpVerified,
      streakCount: streakCount ?? this.streakCount,
      lastStreakDate: lastStreakDate ?? this.lastStreakDate,
      pendingStreakSync: pendingStreakSync ?? this.pendingStreakSync,
    );
  }
}