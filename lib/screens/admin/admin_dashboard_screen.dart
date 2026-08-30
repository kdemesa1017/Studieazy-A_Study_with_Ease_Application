import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_service.dart';
import 'admin_tickets_view.dart';
import 'admin_errors_view.dart';
import 'admin_backup_view.dart';
import 'admin_roles_view.dart';
import 'admin_users_view.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _selectedTab = 0;
  SystemMetrics? _metrics;
  bool _isLoadingMetrics = true;

  @override
  void initState() {
    super.initState();
    _fetchMetrics();
  }

  Future<void> _fetchMetrics() async {
    setState(() => _isLoadingMetrics = true);
    final m = await AdminService.fetchMetrics();
    if (!mounted) return;
    setState(() {
      _metrics = m;
      _isLoadingMetrics = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surfaceBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    const primaryColor = Color(0xFF5C4EE8);

    // Auth & Permission Guard
    if (user == null || !user.isAdmin) {
      return Scaffold(
        backgroundColor: scaffoldBg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.gpp_bad_rounded, size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text(
                'Access Denied',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('You do not have administrative privileges.'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      );
    }

    final isWide = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: surfaceBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: isWide
            ? Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shield_rounded, size: 16, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'ADMIN PORTAL',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Control Center',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.shield_rounded, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Admin Portal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
        actions: isWide
            ? [
                IconButton(
                  tooltip: 'Refresh Metrics',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _fetchMetrics,
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                  ),
                  icon: const Icon(Icons.exit_to_app_rounded, size: 18),
                  label: const Text('Exit Portal', style: TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: () => context.go('/'),
                ),
                const SizedBox(width: 8),
              ]
            : [
                IconButton(
                  tooltip: 'Refresh Metrics',
                  icon: const Icon(Icons.refresh_rounded, size: 22),
                  onPressed: _fetchMetrics,
                ),
                IconButton(
                  tooltip: 'Exit Portal',
                  icon: const Icon(Icons.exit_to_app_rounded, size: 22),
                  onPressed: () => context.go('/'),
                ),
                const SizedBox(width: 4),
              ],
      ),
      body: Row(
        children: [
          // Desktop Sidebar Navigation
          if (isWide)
            Container(
              width: 240,
              decoration: BoxDecoration(
                color: surfaceBg,
                border: Border(right: BorderSide(color: borderColor)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _navItem(0, Icons.dashboard_outlined, Icons.dashboard_rounded, 'Overview & Stats', primaryColor),
                  _navItem(1, Icons.people_alt_outlined, Icons.people_alt_rounded, 'User Management', primaryColor),
                  _navItem(2, Icons.confirmation_number_outlined, Icons.confirmation_number_rounded, 'Support Tickets', primaryColor),
                  _navItem(3, Icons.bug_report_outlined, Icons.bug_report_rounded, 'Crash & Errors', primaryColor),
                  _navItem(4, Icons.backup_outlined, Icons.backup_rounded, 'Backup & Restore', primaryColor),
                  _navItem(5, Icons.manage_accounts_outlined, Icons.manage_accounts_rounded, 'RBAC & Roles', primaryColor),
                  const Spacer(),
                  // Admin user info
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: primaryColor.withValues(alpha: 0.2),
                          child: Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : 'A',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                user.isSuperAdmin ? 'Super Admin' : 'Admin',
                                style: const TextStyle(fontSize: 10.5, color: Colors.grey),
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

          // Main View Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildCurrentTab(isDark, surfaceBg, borderColor, primaryColor),
            ),
          ),
        ],
      ),
      bottomNavigationBar: !isWide
          ? BottomNavigationBar(
              currentIndex: _selectedTab,
              onTap: (index) => setState(() => _selectedTab = index),
              selectedItemColor: primaryColor,
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              backgroundColor: surfaceBg,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Overview'),
                BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Users'),
                BottomNavigationBarItem(icon: Icon(Icons.confirmation_number_rounded), label: 'Tickets'),
                BottomNavigationBarItem(icon: Icon(Icons.bug_report_rounded), label: 'Errors'),
                BottomNavigationBarItem(icon: Icon(Icons.backup_rounded), label: 'Backup'),
                BottomNavigationBarItem(icon: Icon(Icons.manage_accounts_rounded), label: 'Roles'),
              ],
            )
          : null,
    );
  }

  Widget _navItem(int index, IconData unselectedIcon, IconData selectedIcon, String label, Color primaryColor) {
    final isSelected = _selectedTab == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? primaryColor.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        dense: true,
        leading: Icon(
          isSelected ? selectedIcon : unselectedIcon,
          color: isSelected ? primaryColor : Colors.grey,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13.5,
            color: isSelected
                ? primaryColor
                : (isDark ? Colors.grey.shade300 : const Color(0xFF334155)),
          ),
        ),
        onTap: () => setState(() => _selectedTab = index),
      ),
    );
  }

  Widget _buildCurrentTab(bool isDark, Color surfaceBg, Color borderColor, Color primaryColor) {
    switch (_selectedTab) {
      case 0:
        return _buildOverviewTab(isDark, surfaceBg, borderColor, primaryColor);
      case 1:
        return const AdminUsersView();
      case 2:
        return const AdminTicketsView();
      case 3:
        return const AdminErrorsView();
      case 4:
        return const AdminBackupView();
      case 5:
        return const AdminRolesView();
      default:
        return const Center(child: Text('Unknown tab'));
    }
  }

  Widget _buildOverviewTab(bool isDark, Color surfaceBg, Color borderColor, Color primaryColor) {
    if (_isLoadingMetrics) {
      return const Center(child: CircularProgressIndicator());
    }

    final m = _metrics ?? SystemMetrics(
      totalUsers: 0,
      totalQuizzes: 0,
      totalQuestions: 0,
      openTickets: 0,
      totalErrorsToday: 0,
      activeAdmins: 1,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'System Health & Operations 🚀',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Database status is normal. ${m.openTickets} open support tickets and ${m.totalErrorsToday} error logs in the last 24 hours.',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade300),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, color: Colors.green, size: 10),
                      const SizedBox(width: 6),
                      Text(
                        '${m.systemHealthScore.toStringAsFixed(0)}% HEALTH',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stat Cards Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 700 ? 4 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.4,
                children: [
                  _statCard('Total Users', '${m.totalUsers}', Icons.people_alt_outlined, Colors.blue, surfaceBg, borderColor, isDark),
                  _statCard('Total Quizzes', '${m.totalQuizzes}', Icons.folder_copy_outlined, primaryColor, surfaceBg, borderColor, isDark),
                  _statCard('Open Tickets', '${m.openTickets}', Icons.confirmation_number_outlined, Colors.orange, surfaceBg, borderColor, isDark),
                  _statCard('Errors (24h)', '${m.totalErrorsToday}', Icons.bug_report_outlined, Colors.redAccent, surfaceBg, borderColor, isDark),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Quick Action Hub
          Text(
            'Quick Administrative Tools',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _quickActionTile(
                  icon: Icons.confirmation_number_rounded,
                  title: 'Review Tickets',
                  subtitle: '${m.openTickets} pending inquiries',
                  color: Colors.orange,
                  surfaceBg: surfaceBg,
                  borderColor: borderColor,
                  isDark: isDark,
                  onTap: () => setState(() => _selectedTab = 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _quickActionTile(
                  icon: Icons.cloud_download_rounded,
                  title: 'Export DB Backup',
                  subtitle: 'Save JSON database snapshot',
                  color: primaryColor,
                  surfaceBg: surfaceBg,
                  borderColor: borderColor,
                  isDark: isDark,
                  onTap: () => setState(() => _selectedTab = 3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _quickActionTile(
                  icon: Icons.bug_report_rounded,
                  title: 'Inspect Errors',
                  subtitle: 'Real-time stack traces',
                  color: Colors.redAccent,
                  surfaceBg: surfaceBg,
                  borderColor: borderColor,
                  isDark: isDark,
                  onTap: () => setState(() => _selectedTab = 2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _quickActionTile(
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'Assign Roles',
                  subtitle: '${m.activeAdmins} active admins',
                  color: Colors.teal,
                  surfaceBg: surfaceBg,
                  borderColor: borderColor,
                  isDark: isDark,
                  onTap: () => setState(() => _selectedTab = 4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, Color bg, Color border, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color surfaceBg,
    required Color borderColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 18),
          ],
        ),
      ),
    );
  }
}
