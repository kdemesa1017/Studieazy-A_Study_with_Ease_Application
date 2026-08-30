import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/admin_service.dart';

import '../../widgets/sweet_alert_dialog.dart';

class AdminRolesView extends StatefulWidget {
  const AdminRolesView({super.key});

  @override
  State<AdminRolesView> createState() => _AdminRolesViewState();
}

class _AdminRolesViewState extends State<AdminRolesView> {
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _users = [];
  bool _isLoading = false;
  String? _errorMessage;

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
      final results = await AdminService.searchUsers(_searchController.text);
      if (!mounted) return;
      setState(() {
        _users = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleRole(UserModel user) async {
    final isCurrentlyAdmin = user.isAdmin;
    final isSuper = user.isSuperAdmin;

    if (isSuper) {
      await SweetAlert.showWarning(
        context,
        title: 'Protected Account',
        subtitle: 'The Super-Admin role is permanent and cannot be modified.',
        showCancelButton: false,
      );
      return;
    }

    final newRole = isCurrentlyAdmin ? 'user' : 'admin';
    final actionName = isCurrentlyAdmin ? 'Demote to User' : 'Promote to Admin';

    final confirmed = await SweetAlert.showWarning(
      context,
      title: '$actionName?',
      subtitle: 'Are you sure you want to change the role of ${user.name} (${user.email}) to "$newRole"?',
      confirmButtonText: actionName,
      confirmButtonColor: isCurrentlyAdmin ? Colors.redAccent : const Color(0xFF5C4EE8),
      customContent: !isCurrentlyAdmin
          ? Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Colors.amber, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Security Tip: Inform the new admin to update their password.',
                      style: TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );

    if (confirmed == true) {
      try {
        await AdminService.updateUserRole(userId: user.id, newRole: newRole);
        _loadUsers();
        if (mounted) {
          await SweetAlert.showSuccess(
            context,
            title: 'Role Updated!',
            subtitle: 'Successfully set ${user.name} as "$newRole".',
          );
        }
      } catch (e) {
        if (mounted) {
          await SweetAlert.showError(
            context,
            title: 'Update Failed',
            subtitle: e.toString(),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    const primaryColor = Color(0xFF5C4EE8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Bar
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search user by name, email, or school...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: () {
                _searchController.clear();
                _loadUsers();
              },
            ),
            filled: true,
            fillColor: cardBg,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: cardBorder),
            ),
          ),
          onChanged: (val) => _loadUsers(),
        ),
        const SizedBox(height: 12),

        // Header with count and refresh
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Registered Accounts (${_users.length})',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Reload Users',
              onPressed: _loadUsers,
            ),
          ],
        ),
        const SizedBox(height: 6),

        // User list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shield_outlined, size: 48, color: Colors.orange),
                            const SizedBox(height: 12),
                            const Text(
                              'Firestore Rules Need Update',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Please publish the updated rules in Firebase Console > Firestore > Rules.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Retry'),
                              onPressed: _loadUsers,
                            ),
                          ],
                        ),
                      ),
                    )
                  : _users.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey.shade500),
                              const SizedBox(height: 12),
                              Text(
                                'No users found matching query',
                                style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  _searchController.clear();
                                  _loadUsers();
                                },
                                child: const Text('Show All Users'),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _users.length,
                          separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                        final user = _users[index];
                        final isSuper = user.isSuperAdmin;
                        final isAdmin = user.isAdmin;

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSuper
                                  ? Colors.amber.withValues(alpha: 0.5)
                                  : isAdmin
                                      ? primaryColor.withValues(alpha: 0.4)
                                      : cardBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Avatar Circle
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: isSuper
                                    ? Colors.amber.withValues(alpha: 0.2)
                                    : isAdmin
                                        ? primaryColor.withValues(alpha: 0.2)
                                        : Colors.grey.withValues(alpha: 0.2),
                                child: Text(
                                  user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSuper
                                        ? Colors.amber.shade700
                                        : isAdmin
                                            ? primaryColor
                                            : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          user.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (isSuper)
                                          _roleBadge('SUPER ADMIN', Colors.amber)
                                        else if (isAdmin)
                                          _roleBadge('ADMIN', primaryColor)
                                        else
                                          _roleBadge('USER', Colors.grey),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      user.email,
                                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                    ),
                                    if ((user.school ?? '').isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        user.school!,
                                        style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Toggle Action
                              if (!isSuper)
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    side: BorderSide(
                                      color: isAdmin ? Colors.redAccent : primaryColor,
                                    ),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => _toggleRole(user),
                                  child: Text(
                                    isAdmin ? 'Demote' : 'Make Admin',
                                    style: TextStyle(
                                      color: isAdmin ? Colors.redAccent : primaryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _roleBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.bold),
      ),
    );
  }
}
