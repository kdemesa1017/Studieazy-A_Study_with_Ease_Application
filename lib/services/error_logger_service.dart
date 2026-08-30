import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ErrorLogModel {
  final String id;
  final String message;
  final String? stackTrace;
  final String source;
  final String? userId;
  final String platform;
  final DateTime timestamp;
  final String severity; // 'info', 'warning', 'error', 'fatal'
  final bool resolved;

  ErrorLogModel({
    required this.id,
    required this.message,
    this.stackTrace,
    required this.source,
    this.userId,
    required this.platform,
    required this.timestamp,
    this.severity = 'error',
    this.resolved = false,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'message': message,
      'stackTrace': stackTrace,
      'source': source,
      'userId': userId,
      'platform': platform,
      'timestamp': timestamp.toIso8601String(),
      'severity': severity,
      'resolved': resolved,
    };
  }

  factory ErrorLogModel.fromFirestore(Map<String, dynamic> data) {
    return ErrorLogModel(
      id: data['id'] as String? ?? '',
      message: data['message'] as String? ?? 'Unknown error',
      stackTrace: data['stackTrace'] as String?,
      source: data['source'] as String? ?? 'app',
      userId: data['userId'] as String?,
      platform: data['platform'] as String? ?? 'unknown',
      timestamp: data['timestamp'] != null
          ? DateTime.tryParse(data['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      severity: data['severity'] as String? ?? 'error',
      resolved: (data['resolved'] as bool?) ?? false,
    );
  }
}

class ErrorLoggerService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'error_logs';

  /// Captures and stores an error record in Firestore.
  static Future<void> logError({
    required String message,
    dynamic error,
    StackTrace? stackTrace,
    String source = 'General',
    String? userId,
    String severity = 'error',
  }) async {
    try {
      final docRef = _firestore.collection(_collection).doc();
      final platform = kIsWeb
          ? 'Web'
          : defaultTargetPlatform.name;

      final log = ErrorLogModel(
        id: docRef.id,
        message: '$message${error != null ? ' - $error' : ''}',
        stackTrace: stackTrace?.toString(),
        source: source,
        userId: userId,
        platform: platform,
        timestamp: DateTime.now(),
        severity: severity,
        resolved: false,
      );

      await docRef.set(log.toFirestore());
      debugPrint('[ErrorLogger] Recorded error: $message ($source)');
    } catch (e) {
      debugPrint('[ErrorLogger] Failed to write error log to Firestore: $e');
    }
  }

  /// Stream of recent error logs sorted by newest first.
  static Stream<List<ErrorLogModel>> streamLogs({int limit = 50}) {
    return _firestore
        .collection(_collection)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ErrorLogModel.fromFirestore(d.data())).toList());
  }

  /// Mark an error as resolved.
  static Future<void> resolveError(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).update({'resolved': true});
    } catch (e) {
      debugPrint('[ErrorLogger] Failed to resolve error: $e');
    }
  }

  /// Clear all error logs from Firestore.
  static Future<void> clearAllErrors() async {
    try {
      final snap = await _firestore.collection(_collection).limit(200).get();
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[ErrorLogger] Failed to clear error logs: $e');
    }
  }
}
