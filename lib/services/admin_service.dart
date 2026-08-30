import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'error_logger_service.dart';

// ── Support Ticket Model ──────────────────────────────────────────────────────

class SupportTicketModel {
  final String id;
  final String userId;
  final String userEmail;
  final String userName;
  final String subject;
  final String message;
  final String category; // 'Bug / Error', 'Account Issue', 'Flashcard / Quiz', 'Feature Request', 'Other'
  final String status; // 'open', 'in_progress', 'resolved'
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? adminNotes;

  SupportTicketModel({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.subject,
    required this.message,
    required this.category,
    this.status = 'open',
    required this.createdAt,
    this.resolvedAt,
    this.adminNotes,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'subject': subject,
      'message': message,
      'category': category,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
      'adminNotes': adminNotes,
    };
  }

  factory SupportTicketModel.fromFirestore(Map<String, dynamic> data) {
    return SupportTicketModel(
      id: data['id'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      userEmail: data['userEmail'] as String? ?? '',
      userName: data['userName'] as String? ?? 'User',
      subject: data['subject'] as String? ?? 'No Subject',
      message: data['message'] as String? ?? '',
      category: data['category'] as String? ?? 'General',
      status: data['status'] as String? ?? 'open',
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      resolvedAt: data['resolvedAt'] != null
          ? DateTime.tryParse(data['resolvedAt'] as String)
          : null,
      adminNotes: data['adminNotes'] as String?,
    );
  }
}

// ── System Metrics Model ──────────────────────────────────────────────────────

class SystemMetrics {
  final int totalUsers;
  final int totalQuizzes;
  final int totalQuestions;
  final int openTickets;
  final int totalErrorsToday;
  final int activeAdmins;

  SystemMetrics({
    required this.totalUsers,
    required this.totalQuizzes,
    required this.totalQuestions,
    required this.openTickets,
    required this.totalErrorsToday,
    required this.activeAdmins,
  });

  double get systemHealthScore {
    if (totalErrorsToday == 0) return 100.0;
    if (totalErrorsToday <= 3) return 96.0;
    if (totalErrorsToday <= 10) return 88.0;
    return 75.0;
  }
}

// ── Admin Service ─────────────────────────────────────────────────────────────

class AdminService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Metrics ────────────────────────────────────────────────────────────────

  static Future<SystemMetrics> fetchMetrics() async {
    try {
      final usersSnap = await _firestore.collection('users').get();
      final quizzesSnap = await _firestore.collection('quizzes').get();
      final questionsSnap = await _firestore.collection('questions').get();
      final ticketsSnap = await _firestore
          .collection('support_tickets')
          .where('status', isEqualTo: 'open')
          .get();

      final todayStart = DateTime.now().subtract(const Duration(hours: 24));
      final errorsSnap = await _firestore
          .collection('error_logs')
          .where('timestamp', isGreaterThanOrEqualTo: todayStart.toIso8601String())
          .get();

      int adminCount = 0;
      for (final doc in usersSnap.docs) {
        final role = doc.data()['role'] as String? ?? 'user';
        final email = doc.data()['email'] as String? ?? '';
        if (role == 'admin' || role == 'superadmin' || email.toLowerCase() == 'demesakurtdaryl@gmail.com') {
          adminCount++;
        }
      }

      return SystemMetrics(
        totalUsers: usersSnap.size,
        totalQuizzes: quizzesSnap.size,
        totalQuestions: questionsSnap.size,
        openTickets: ticketsSnap.size,
        totalErrorsToday: errorsSnap.size,
        activeAdmins: adminCount,
      );
    } catch (e) {
      debugPrint('[AdminService] Error fetching metrics: $e');
      return SystemMetrics(
        totalUsers: 0,
        totalQuizzes: 0,
        totalQuestions: 0,
        openTickets: 0,
        totalErrorsToday: 0,
        activeAdmins: 1,
      );
    }
  }

  // ── Support Tickets ────────────────────────────────────────────────────────

  static Stream<List<SupportTicketModel>> streamTickets() {
    return _firestore
        .collection('support_tickets')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => SupportTicketModel.fromFirestore(d.data())).toList());
  }

  static Future<void> createTicket({
    required String userId,
    required String userEmail,
    required String userName,
    required String subject,
    required String message,
    required String category,
  }) async {
    try {
      final docRef = _firestore.collection('support_tickets').doc();
      final ticket = SupportTicketModel(
        id: docRef.id,
        userId: userId,
        userEmail: userEmail,
        userName: userName,
        subject: subject,
        message: message,
        category: category,
        status: 'open',
        createdAt: DateTime.now(),
      );
      await docRef.set(ticket.toFirestore());
    } catch (e) {
      ErrorLoggerService.logError(
        message: 'Failed to create support ticket',
        error: e,
        source: 'AdminService.createTicket',
        userId: userId,
      );
      rethrow;
    }
  }

  static Future<void> updateTicketStatus({
    required String ticketId,
    required String status,
    String? adminNotes,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': status,
        if (status == 'resolved') 'resolvedAt': DateTime.now().toIso8601String(),
        if (adminNotes != null) 'adminNotes': adminNotes,
      };
      await _firestore.collection('support_tickets').doc(ticketId).update(updateData);
    } catch (e) {
      debugPrint('[AdminService] Error updating ticket: $e');
      rethrow;
    }
  }

  // ── Database Backup & Restore ──────────────────────────────────────────────

  /// Export Firestore collections as a single structured JSON string.
  static Future<String> exportDatabaseBackup() async {
    try {
      final usersSnap = await _firestore.collection('users').get();
      final quizzesSnap = await _firestore.collection('quizzes').get();
      final questionsSnap = await _firestore.collection('questions').get();
      final ticketsSnap = await _firestore.collection('support_tickets').get();

      final backupData = {
        'version': '1.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'collections': {
          'users': usersSnap.docs.map((d) => d.data()).toList(),
          'quizzes': quizzesSnap.docs.map((d) => d.data()).toList(),
          'questions': questionsSnap.docs.map((d) => d.data()).toList(),
          'support_tickets': ticketsSnap.docs.map((d) => d.data()).toList(),
        },
      };

      return jsonEncode(backupData);
    } catch (e) {
      ErrorLoggerService.logError(
        message: 'Database backup export failed',
        error: e,
        source: 'AdminService.exportDatabaseBackup',
      );
      rethrow;
    }
  }

  /// Restore Firestore collections from backup JSON.
  static Future<int> restoreDatabaseBackup(Map<String, dynamic> backupData) async {
    try {
      int restoredCount = 0;
      final collections = backupData['collections'] as Map<String, dynamic>? ?? {};

      for (final entry in collections.entries) {
        final collectionName = entry.key;
        final docsList = (entry.value as List<dynamic>?) ?? [];

        for (final doc in docsList) {
          final docMap = doc as Map<String, dynamic>;
          final docId = docMap['id'] as String? ?? _firestore.collection(collectionName).doc().id;
          await _firestore.collection(collectionName).doc(docId).set(docMap, SetOptions(merge: true));
          restoredCount++;
        }
      }

      return restoredCount;
    } catch (e) {
      ErrorLoggerService.logError(
        message: 'Database restore failed',
        error: e,
        source: 'AdminService.restoreDatabaseBackup',
      );
      rethrow;
    }
  }

  // ── Role-Based Access Control (RBAC) ───────────────────────────────────────

  /// Search all users in Firestore.
  static Future<List<UserModel>> searchUsers(String query) async {
    try {
      final snap = await _firestore.collection('users').get();
      final List<UserModel> rawUsers = [];
      for (final doc in snap.docs) {
        try {
          final data = Map<String, dynamic>.from(doc.data());
          if (data['id'] == null || (data['id'] as String).isEmpty) {
            data['id'] = doc.id;
          }
          rawUsers.add(UserModel.fromFirestore(data));
        } catch (err) {
          debugPrint('[AdminService] Error parsing user doc ${doc.id}: $err');
        }
      }

      // Deduplicate by email (or user ID if email is missing)
      final Map<String, UserModel> uniqueMap = {};
      for (final user in rawUsers) {
        final emailKey = user.email.trim().toLowerCase();
        final key = emailKey.isNotEmpty ? emailKey : user.id;

        if (!uniqueMap.containsKey(key)) {
          uniqueMap[key] = user;
        } else {
          // Merge: keep the richer profile (e.g., has admin role, last active, school)
          final existing = uniqueMap[key]!;
          final preferNew = (user.isSuperAdmin && !existing.isSuperAdmin) ||
              (user.isAdmin && !existing.isAdmin) ||
              (user.lastActiveAt != null && existing.lastActiveAt == null) ||
              (user.school != null && existing.school == null);
          if (preferNew) {
            uniqueMap[key] = user;
          }
        }
      }

      final allUsers = uniqueMap.values.toList();

      if (query.trim().isEmpty) return allUsers;

      final q = query.toLowerCase().trim();
      return allUsers.where((u) {
        return u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q) ||
            (u.school?.toLowerCase().contains(q) ?? false);
      }).toList();
    } catch (e) {
      debugPrint('[AdminService] Error searching users: $e');
      return [];
    }
  }

  /// Change user role (e.g. 'admin' or 'user').
  static Future<void> updateUserRole({
    required String userId,
    required String newRole,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'role': newRole,
      });
    } catch (e) {
      ErrorLoggerService.logError(
        message: 'Failed to update user role to $newRole',
        error: e,
        source: 'AdminService.updateUserRole',
        userId: userId,
      );
      rethrow;
    }
  }

  // ── User Deletion ─────────────────────────────────────────────────────────────

  /// Deletes all Firestore data for [userId]: user doc, quizzes, questions,
  /// support tickets, and error logs. Returns a summary of deleted counts.
  static Future<Map<String, int>> deleteUserAndAllData(String userId) async {
    int quizCount = 0;
    int questionCount = 0;
    int ticketCount = 0;

    try {
      // Delete quizzes owned by user
      final quizSnap = await _firestore
          .collection('quizzes')
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in quizSnap.docs) {
        await doc.reference.delete();
        quizCount++;
      }

      // Delete questions owned by user
      final questionSnap = await _firestore
          .collection('questions')
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in questionSnap.docs) {
        await doc.reference.delete();
        questionCount++;
      }

      // Delete support tickets
      final ticketSnap = await _firestore
          .collection('support_tickets')
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in ticketSnap.docs) {
        await doc.reference.delete();
        ticketCount++;
      }

      // Delete error logs by user
      final logsSnap = await _firestore
          .collection('error_logs')
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in logsSnap.docs) {
        await doc.reference.delete();
      }

      // Finally delete the user document itself
      await _firestore.collection('users').doc(userId).delete();

      return {
        'quizzes': quizCount,
        'questions': questionCount,
        'tickets': ticketCount,
      };
    } catch (e) {
      ErrorLoggerService.logError(
        message: 'Failed to delete user and all data',
        error: e,
        source: 'AdminService.deleteUserAndAllData',
        userId: userId,
      );
      rethrow;
    }
  }
}
