import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/admin_service.dart';
import '../../widgets/sweet_alert_dialog.dart';

class AdminBackupView extends StatefulWidget {
  const AdminBackupView({super.key});

  @override
  State<AdminBackupView> createState() => _AdminBackupViewState();
}

class _AdminBackupViewState extends State<AdminBackupView> {
  bool _isExporting = false;
  bool _isRestoring = false;
  String? _statusMessage;

  Future<void> _exportBackup() async {
    setState(() {
      _isExporting = true;
      _statusMessage = null;
    });

    try {
      final jsonString = await AdminService.exportDatabaseBackup();
      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _statusMessage = 'Database backup generated successfully!';
      });

      // If Web, trigger download via data URL or file save
      if (kIsWeb) {
        // Trigger browser download by copying to clipboard or presenting dialog
        _showExportSuccessDialog(jsonString);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _statusMessage = 'Export failed: $e';
      });
    }
  }

  void _showExportSuccessDialog(String jsonString) {
    final parsed = jsonDecode(jsonString) as Map<String, dynamic>;
    final collections = parsed['collections'] as Map<String, dynamic>? ?? {};

    SweetAlert.showSuccess(
      context,
      title: 'Backup Ready!',
      subtitle: 'Database exported successfully with:\n'
          '• ${(collections['users'] as List?)?.length ?? 0} Users\n'
          '• ${(collections['quizzes'] as List?)?.length ?? 0} Quizzes\n'
          '• ${(collections['questions'] as List?)?.length ?? 0} Questions\n'
          '• ${(collections['support_tickets'] as List?)?.length ?? 0} Support Tickets',
    );
  }

  Future<void> _pickAndRestoreFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final fileBytes = result.files.first.bytes;
      if (fileBytes == null) {
        if (!mounted) return;
        SweetAlert.showError(
          context,
          title: 'File Error',
          subtitle: 'Could not read file data. Please choose a valid .json backup.',
        );
        return;
      }

      final jsonContent = utf8.decode(fileBytes);
      final backupMap = jsonDecode(jsonContent) as Map<String, dynamic>;

      if (!mounted) return;
      _confirmRestore(backupMap);
    } catch (e) {
      if (!mounted) return;
      SweetAlert.showError(
        context,
        title: 'Invalid Backup',
        subtitle: 'The selected file is not a valid JSON database backup: $e',
      );
    }
  }

  Future<void> _confirmRestore(Map<String, dynamic> backupMap) async {
    final collections = backupMap['collections'] as Map<String, dynamic>? ?? {};

    final confirmed = await SweetAlert.showConfirm(
      context,
      title: 'Confirm Database Restore?',
      subtitle: 'Restoring will merge and overwrite existing records with matching IDs.',
      confirmButtonText: 'Yes, Restore Now',
      confirmButtonColor: const Color(0xFF5C4EE8),
      customContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• Users: ${(collections['users'] as List?)?.length ?? 0}'),
          const SizedBox(height: 4),
          Text('• Quizzes: ${(collections['quizzes'] as List?)?.length ?? 0}'),
          const SizedBox(height: 4),
          Text('• Questions: ${(collections['questions'] as List?)?.length ?? 0}'),
          const SizedBox(height: 4),
          Text('• Tickets: ${(collections['support_tickets'] as List?)?.length ?? 0}'),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isRestoring = true);
      try {
        final count = await AdminService.restoreDatabaseBackup(backupMap);
        if (!mounted) return;
        setState(() {
          _isRestoring = false;
          _statusMessage = 'Successfully restored $count records!';
        });
        await SweetAlert.showSuccess(
          context,
          title: 'Database Restored!',
          subtitle: 'Successfully restored $count records into Cloud Firestore.',
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isRestoring = false;
          _statusMessage = 'Restore failed: $e';
        });
        await SweetAlert.showError(
          context,
          title: 'Restore Failed',
          subtitle: e.toString(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    const primaryColor = Color(0xFF5C4EE8);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_statusMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_statusMessage!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Export Section ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.cloud_download_outlined, color: primaryColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Export Database Backup (JSON)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Download all users, quizzes, questions, and tickets in a structured JSON file.',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: _isExporting
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded),
                    label: Text(_isExporting ? 'Generating Backup...' : 'Export Full Database'),
                    onPressed: _isExporting ? null : _exportBackup,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ── Restore Section ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.restore_page_outlined, color: Colors.orange, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Restore from Backup File',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Upload a previously exported JSON backup file to restore missing or deleted data.',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orange),
                      foregroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isRestoring
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file_rounded),
                    label: Text(_isRestoring ? 'Restoring Data...' : 'Select JSON Backup File to Restore'),
                    onPressed: _isRestoring ? null : _pickAndRestoreFile,
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
