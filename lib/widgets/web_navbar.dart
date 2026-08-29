import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

class WebNavbar extends ConsumerWidget implements PreferredSizeWidget {
  final int currentIndex;

  const WebNavbar({
    super.key,
    required this.currentIndex,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUserAsync = ref.watch(currentUserProvider);
    final currentUser = currentUserAsync.valueOrNull;

    final navItems = [
      {'label': 'Home', 'route': '/', 'icon': Icons.home_rounded},
      {'label': 'My Quizzes', 'route': '/my-quizzes', 'icon': Icons.folder_rounded},
      {'label': 'Create Quiz', 'route': '/create-quiz', 'icon': Icons.add_circle_outline_rounded},
      {'label': 'AI Generator', 'route': '/ai-generator', 'icon': Icons.auto_awesome_rounded, 'isSpecial': true},
      {'label': 'Study Mode', 'route': '/study', 'icon': Icons.school_rounded},
    ];

    return Container(
      height: preferredSize.height,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF131726).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              // ── Brand Logo & Name ──────────────────────────────────────
              InkWell(
                onTap: () => context.go('/'),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          'assets/images/Logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.school,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'SelfStudy',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          'WEB',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6366F1),
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 32),

              // ── Desktop Navigation Tabs ──────────────────────────────────
              Expanded(
                child: Row(
                  children: List.generate(navItems.length, (index) {
                    final item = navItems[index];
                    final route = item['route'] as String;
                    final label = item['label'] as String;
                    final icon = item['icon'] as IconData;
                    final isSpecial = item['isSpecial'] == true;

                    final currentRoute = GoRouterState.of(context).matchedLocation;
                    final isSelected = currentRoute == route ||
                        (route == '/' && currentRoute == '/') ||
                        (route == '/my-quizzes' && currentRoute.startsWith('/quiz/'));

                    if (isSpecial) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => context.go(route),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: InkWell(
                        onTap: () => context.go(route),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark
                                    ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                                    : const Color(0xFF6366F1).withValues(alpha: 0.1))
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                icon,
                                size: 18,
                                color: isSelected
                                    ? const Color(0xFF6366F1)
                                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected
                                      ? const Color(0xFF6366F1)
                                      : (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // ── Right Action Controls ───────────────────────────────────
              Row(
                children: [
                  // Create Deck Shortcut Button
                  ElevatedButton.icon(
                    onPressed: () => context.go('/create-quiz'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'New Quiz',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Dark / Light Theme Toggle Button
                  IconButton(
                    onPressed: () {
                      final currentTheme = ref.read(themeModeProvider);
                      final nextTheme = currentTheme == ThemeMode.dark
                          ? ThemeMode.light
                          : ThemeMode.dark;
                      ref.read(themeModeProvider.notifier).setThemeMode(nextTheme);
                    },
                    icon: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: isDark ? Colors.amber.shade300 : const Color(0xFF475569),
                    ),
                    tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                  ),

                  const SizedBox(width: 8),

                  // User Avatar & Menu Dropdown
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'profile') {
                        context.go('/profile');
                      } else if (value == 'logout') {
                        await ref.read(authServiceProvider).signOut();
                        if (context.mounted) context.go('/login');
                      }
                    },
                    offset: const Offset(0, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF6366F1),
                        backgroundImage: currentUser?.profileImageUrl != null
                            ? NetworkImage(currentUser!.profileImageUrl!)
                            : null,
                        child: currentUser?.profileImageUrl == null
                            ? Text(
                                currentUser?.name.isNotEmpty == true
                                    ? currentUser!.name[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              )
                            : null,
                      ),
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        enabled: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currentUser?.name ?? 'User',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              currentUser?.email ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const Divider(height: 16),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'profile',
                        child: Row(
                          children: [
                            Icon(Icons.person_outline_rounded, size: 18),
                            SizedBox(width: 10),
                            Text('My Profile'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
                            SizedBox(width: 10),
                            Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
