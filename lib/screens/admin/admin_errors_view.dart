import 'package:flutter/material.dart';
import '../../services/error_logger_service.dart';
import '../../widgets/sweet_alert_dialog.dart';

class AdminErrorsView extends StatefulWidget {
  const AdminErrorsView({super.key});

  @override
  State<AdminErrorsView> createState() => _AdminErrorsViewState();
}

class _AdminErrorsViewState extends State<AdminErrorsView> {
  bool _hideResolved = false;

  void _simulateTestError() {
    ErrorLoggerService.logError(
      message: 'Test crash error captured by Admin Monitor',
      error: 'SimulatedException: Verification of real-time monitoring',
      source: 'AdminErrorsView.test',
      severity: 'warning',
    );
    SweetAlert.showSuccess(
      context,
      title: 'Test Error Logged!',
      subtitle: 'A simulated test exception has been dispatched to Firestore crash logs.',
    );
  }

  Future<void> _confirmClearAll(BuildContext context, bool isDark) async {
    final confirmed = await SweetAlert.showConfirm(
      context,
      title: 'Clear All Error Logs?',
      subtitle: 'This will permanently delete all logged errors and crashes from Firestore.',
      confirmButtonText: 'Yes, Clear All',
      confirmButtonColor: Colors.redAccent,
    );

    if (confirmed == true) {
      await ErrorLoggerService.clearAllErrors();
      if (!context.mounted) return;
      await SweetAlert.showSuccess(
        context,
        title: 'Logs Cleared!',
        subtitle: 'All error records have been purged from the database.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Controls Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                FilterChip(
                  label: const Text('Hide Resolved'),
                  selected: _hideResolved,
                  selectedColor: const Color(0xFF5C4EE8).withValues(alpha: 0.2),
                  onSelected: (val) => setState(() => _hideResolved = val),
                ),
              ],
            ),
            Row(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.bug_report_outlined, size: 16),
                  label: const Text('Simulate Error', style: TextStyle(fontSize: 12)),
                  onPressed: _simulateTestError,
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Clear All Logs',
                  icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                  onPressed: () => _confirmClearAll(context, isDark),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Stream of logs
        Expanded(
          child: StreamBuilder<List<ErrorLogModel>>(
            stream: ErrorLoggerService.streamLogs(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allLogs = snapshot.data ?? [];
              final filteredLogs = _hideResolved
                  ? allLogs.where((l) => !l.resolved).toList()
                  : allLogs;

              if (filteredLogs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle_outline_rounded, size: 36, color: Colors.green),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'All Systems Operational',
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No crash or system errors recorded',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: filteredLogs.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final log = filteredLogs[index];
                  final sevColor = log.severity == 'fatal'
                      ? Colors.red.shade700
                      : log.severity == 'error'
                          ? Colors.redAccent
                          : Colors.amber.shade700;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: log.resolved ? cardBorder : sevColor.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: sevColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    log.severity.toUpperCase(),
                                    style: TextStyle(color: sevColor, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '[${log.platform}] ${log.source}',
                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11.5, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            if (log.resolved)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'RESOLVED',
                                  style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              )
                            else
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => ErrorLoggerService.resolveError(log.id),
                                child: const Text('Mark Resolved', style: TextStyle(fontSize: 11.5)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          log.message,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey.shade100 : const Color(0xFF0F172A),
                          ),
                        ),
                        if ((log.stackTrace ?? '').isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text('View Stack Trace', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  log.stackTrace!,
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5, color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              log.userId != null ? 'User: ${log.userId}' : 'Anonymous',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                            Text(
                              '${log.timestamp.month}/${log.timestamp.day} ${log.timestamp.hour}:${log.timestamp.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
