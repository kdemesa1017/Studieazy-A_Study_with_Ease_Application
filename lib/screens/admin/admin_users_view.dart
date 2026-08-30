import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/admin_service.dart';
import '../../widgets/sweet_alert_dialog.dart';

class AdminUsersView extends StatefulWidget {
  const AdminUsersView({super.key});

  @override
  State<AdminUsersView> createState() => _AdminUsersViewState();
}

enum _ActivityFilter { all, active, inactive, never }

class _AdminUsersViewState extends State<AdminUsersView> {
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = false;
  String? _errorMessage;
  _ActivityFilter _filter = _ActivityFilter.all;

  static const _inactiveDays = 30;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await AdminService.searchUsers('');
      results.sort((a, b) {
        final aTime = a.lastActiveAt ?? a.createdAt;
        final bTime = b.lastActiveAt ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
      if (!mounted) return;
      setState(() {
        _allUsers = results;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    final now = DateTime.now();
    setState(() {
      _filteredUsers = _allUsers.where((u) {
        if (query.isNotEmpty) {
          final matches = u.name.toLowerCase().contains(query) ||
              u.email.toLowerCase().contains(query) ||
              (u.school?.toLowerCase().contains(query) ?? false);
          if (!matches) return false;
        }
        switch (_filter) {
          case _ActivityFilter.all:
            return true;
          case _ActivityFilter.active:
            if (u.lastActiveAt == null) return false;
            return now.difference(u.lastActiveAt!).inDays < _inactiveDays;
          case _ActivityFilter.inactive:
            if (u.lastActiveAt == null) return false;
            return now.difference(u.lastActiveAt!).inDays >= _inactiveDays;
          case _ActivityFilter.never:
            return u.lastActiveAt == null;
        }
      }).toList();
    });
  }

  String _formatLastActive(UserModel user) {
    if (user.lastActiveAt == null) return 'Never logged in';
    final diff = DateTime.now().difference(user.lastActiveAt!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 30) return '${diff.inDays} days ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} months ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  Color _activityColor(UserModel user) {
    if (user.lastActiveAt == null) return Colors.grey;
    final days = DateTime.now().difference(user.lastActiveAt!).inDays;
    if (days < 7) return const Color(0xFF22C55E);
    if (days < 30) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  bool _isInactive(UserModel user) {
    if (user.lastActiveAt == null) return true;
    return DateTime.now().difference(user.lastActiveAt!).inDays >= _inactiveDays;
  }

  Future<void> _confirmDelete(UserModel user) async {
    if (user.isSuperAdmin) {
      await SweetAlert.showWarning(
        context,
        title: 'Protected Account',
        subtitle: 'The Super-Admin account is protected and cannot be deleted.',
        showCancelButton: false,
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await SweetAlert.showConfirm(
      context,
      title: 'Delete Account?',
      subtitle: 'Permanently remove ${user.name} (${user.email}) and all their associated data.',
      confirmButtonText: 'Yes, Delete All',
      confirmButtonColor: Colors.redAccent,
      customContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _deleteItem(Icons.person_rounded, 'User profile & credentials', Colors.redAccent, isDark),
          const SizedBox(height: 6),
          _deleteItem(Icons.quiz_rounded, 'All created quizzes & flashcards', Colors.orange, isDark),
          const SizedBox(height: 6),
          _deleteItem(Icons.help_outline_rounded, 'All quiz questions', Colors.orange, isDark),
          const SizedBox(height: 6),
          _deleteItem(Icons.confirmation_number_rounded, 'All support tickets & reports', Colors.orange, isDark),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteUser(user);
    }
  }

  Widget _deleteItem(IconData icon, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white70 : const Color(0xFF334155)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(UserModel user) async {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('Deleting user data...'),
        ]),
      ),
    );
    try {
      final result = await AdminService.deleteUserAndAllData(user.id);
      if (!mounted) return;
      Navigator.of(context).pop();

      await SweetAlert.showSuccess(
        context,
        title: 'Account Deleted',
        subtitle: 'Successfully deleted ${user.name}.\nRemoved ${result['quizzes']} quizzes and ${result['questions']} questions.',
      );

      _loadUsers();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      await SweetAlert.showError(
        context,
        title: 'Deletion Failed',
        subtitle: e.toString(),
      );
    }
  }

  Future<void> _confirmBulkDeleteInactive() async {
    final inactiveUsers = _allUsers.where((u) => _isInactive(u) && !u.isAdmin).toList();
    if (inactiveUsers.isEmpty) {
      await SweetAlert.showWarning(
        context,
        title: 'No Inactive Users',
        subtitle: 'All registered accounts are currently active (within the last $_inactiveDays days).',
        showCancelButton: false,
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await SweetAlert.showConfirm(
      context,
      title: 'Bulk Clean Inactive?',
      subtitle: 'Permanently remove ${inactiveUsers.length} inactive user(s) who haven\'t logged in for $_inactiveDays+ days.',
      confirmButtonText: 'Delete ${inactiveUsers.length} Users',
      confirmButtonColor: Colors.orange,
      customContent: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 180),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: inactiveUsers.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              itemBuilder: (context, index) {
                final u = inactiveUsers[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(children: [
                    const Icon(Icons.person_off_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${u.name} (${u.email})',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                );
              },
            ),
          ),
        ),
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: Row(children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text('Deleting ${inactiveUsers.length} accounts...'),
          ]),
        ),
      );
      int deleted = 0;
      for (final user in inactiveUsers) {
        try {
          await AdminService.deleteUserAndAllData(user.id);
          deleted++;
        } catch (_) {}
      }
      if (!mounted) return;
      Navigator.of(context).pop();

      await SweetAlert.showSuccess(
        context,
        title: 'Bulk Cleanup Complete',
        subtitle: 'Successfully removed $deleted of ${inactiveUsers.length} inactive accounts and freed up database storage.',
      );
      _loadUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    const primaryColor = Color(0xFF5C4EE8);
    final inactiveCount = _allUsers.where((u) => _isInactive(u) && !u.isAdmin).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('User Management', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                Text('${_allUsers.length} registered · $inactiveCount inactive', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500)),
              ]),
            ),
            if (inactiveCount > 0)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.orange, backgroundColor: Colors.orange.withValues(alpha: 0.1), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                label: Text('Clean $inactiveCount', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                onPressed: _confirmBulkDeleteInactive,
              ),
            const SizedBox(width: 6),
            IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'Reload', onPressed: _loadUsers),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search by name, email, or school...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () { _searchController.clear(); _applyFilters(); }) : null,
            filled: true, fillColor: cardBg,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cardBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: cardBorder)),
          ),
          onChanged: (val) => _applyFilters(),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _filterChip('All', _ActivityFilter.all, null, isDark),
            const SizedBox(width: 8),
            _filterChip('Active (<30d)', _ActivityFilter.active, const Color(0xFF22C55E), isDark),
            const SizedBox(width: 8),
            _filterChip('Inactive (30d+)', _ActivityFilter.inactive, Colors.orange, isDark),
            const SizedBox(width: 8),
            _filterChip('Never Logged In', _ActivityFilter.never, Colors.grey, isDark),
          ]),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          children: [
            _legendItem(const Color(0xFF22C55E), '< 7 days'),
            _legendItem(const Color(0xFFF59E0B), '7–30 days'),
            _legendItem(const Color(0xFFEF4444), '30+ days'),
            _legendItem(Colors.grey, 'Never logged in'),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? _buildErrorState()
                  : _filteredUsers.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('No users found', style: TextStyle(color: Colors.grey.shade500)),
                          const SizedBox(height: 8),
                          TextButton(onPressed: () { _searchController.clear(); setState(() => _filter = _ActivityFilter.all); _applyFilters(); }, child: const Text('Clear Filters')),
                        ]))
                      : ListView.separated(
                          itemCount: _filteredUsers.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) => _buildUserCard(_filteredUsers[index], isDark, cardBg, cardBorder, primaryColor),
                        ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, _ActivityFilter value, Color? color, bool isDark) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () { setState(() => _filter = value); _applyFilters(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? (color ?? const Color(0xFF5C4EE8)).withValues(alpha: 0.15) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? (color ?? const Color(0xFF5C4EE8)) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)), width: selected ? 1.5 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (color != null) ...[Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 5)],
          Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.w500, color: selected ? (color ?? const Color(0xFF5C4EE8)) : (isDark ? Colors.grey.shade300 : const Color(0xFF64748B)))),
        ]),
      ),
    );
  }

  Widget _legendItem(Color color, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 11)),
  ]);

  Widget _buildUserCard(UserModel user, bool isDark, Color cardBg, Color cardBorder, Color primaryColor) {
    final actColor = _activityColor(user);
    final inactive = _isInactive(user);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: inactive ? Colors.redAccent.withValues(alpha: 0.25) : cardBorder),
      ),
      child: Row(children: [
        Stack(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: user.isAdmin ? primaryColor.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.18),
            child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: user.isAdmin ? primaryColor : Colors.grey.shade600)),
          ),
          Positioned(bottom: 0, right: 0, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: actColor, shape: BoxShape.circle, border: Border.all(color: cardBg, width: 2)))),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(user.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A)), overflow: TextOverflow.ellipsis)),
            if (user.isSuperAdmin) ...[const SizedBox(width: 5), Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEF4444)]), borderRadius: BorderRadius.circular(4)), child: const Text('SUPER ADMIN', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)))]
            else if (user.isAdmin) ...[const SizedBox(width: 5), Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)), child: Text('ADMIN', style: TextStyle(fontSize: 9, color: primaryColor, fontWeight: FontWeight.bold)))],
          ]),
          const SizedBox(height: 2),
          Text(user.email, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.access_time_rounded, size: 12, color: actColor),
            const SizedBox(width: 4),
            Text(_formatLastActive(user), style: TextStyle(fontSize: 11.5, color: actColor, fontWeight: FontWeight.w600)),
            if (user.school != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.school_outlined, size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 3),
              Flexible(child: Text(user.school!, style: TextStyle(fontSize: 11, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis)),
            ],
          ]),
        ])),
        if (!user.isSuperAdmin)
          IconButton(icon: const Icon(Icons.delete_outline_rounded), tooltip: 'Delete user & all data', color: Colors.redAccent, onPressed: () => _confirmDelete(user)),
      ]),
    );
  }

  Widget _buildErrorState() => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.shield_outlined, size: 48, color: Colors.orange),
      const SizedBox(height: 12),
      const Text('Permission Denied', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 6),
      Text('Update Firestore Rules in Firebase Console > Firestore > Rules.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5)),
      const SizedBox(height: 14),
      ElevatedButton.icon(icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Retry'), onPressed: _loadUsers),
    ]),
  ));
}
