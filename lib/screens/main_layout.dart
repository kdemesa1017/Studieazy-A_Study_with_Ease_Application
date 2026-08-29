import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/web_navbar.dart';

class MainLayout extends ConsumerStatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  int _currentIndex = 0;

  final List<String> _routes = [
    '/',
    '/create-quiz',
    '/ai-generator',
    '/my-quizzes',
    '/study',
    '/profile',
  ];

  final List<String> _labels = [
    'Home',
    'Create',
    'AI Generator',
    'My Quizzes',
    'Study',
    'Profile',
  ];

  final List<IconData> _icons = [
    Icons.home_outlined,
    Icons.add_circle_outline,
    Icons.auto_awesome_outlined,
    Icons.folder_outlined,
    Icons.school_outlined,
    Icons.person_outline,
  ];

  final List<IconData> _selectedIcons = [
    Icons.home,
    Icons.add_circle,
    Icons.auto_awesome,
    Icons.folder,
    Icons.school,
    Icons.person,
  ];

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final currentUser = currentUserAsync.valueOrNull;
    final location = GoRouterState.of(context).matchedLocation;
    final isDesktop = ResponsiveBreakpoints.isDesktop(context);
    
    // Update current index based on route
    for (int i = 0; i < _routes.length; i++) {
      if (location == _routes[i] ||
          (i == 0 && location == '/') ||
          (i == 3 && location.startsWith('/quiz/'))) {
        _currentIndex = i;
        break;
      }
    }

    return Scaffold(
      // Flutter Web: avoids ViewInsets assertion when virtual keyboard dismisses
      resizeToAvoidBottomInset: false,
      appBar: isDesktop
          ? WebNavbar(currentIndex: _currentIndex)
          : AppBar(
              elevation: 0,
              backgroundColor: Colors.transparent,
              title: Text(
                _labels[_currentIndex],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              actions: [
                // Profile Icon in Top Right
                GestureDetector(
                  onTap: () => context.push('/profile'),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Hero(
                      tag: 'profile-avatar',
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.secondary,
                            ],
                          ),
                          shape: BoxShape.circle,
                          image: currentUser?.profileImageUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(currentUser!.profileImageUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: currentUser?.profileImageUrl == null
                            ? Center(
                                child: Text(
                                  currentUser?.name.substring(0, 1).toUpperCase() ?? 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: isDesktop
                  ? WebResponsiveWrapper(child: widget.child)
                  : widget.child,
            ),
          ],
        ),
      ),
      bottomNavigationBar: isDesktop
          ? null
          : Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_routes.length, (index) {
                final isSelected = _currentIndex == index;
                return InkWell(
                  onTap: () {
                    if (_currentIndex != index) {
                      context.go(_routes[index]);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                      horizontal: index == 2 ? 8 : 6,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      // AI tab gets a special gradient highlight
                      gradient: index == 2
                          ? LinearGradient(
                              colors: isSelected
                                  ? const [Color(0xFF6C63FF), Color(0xFF4834D4)]
                                  : [const Color(0xFF6C63FF).withValues(alpha: 0.15), const Color(0xFF4834D4).withValues(alpha: 0.15)],
                            )
                          : null,
                      color: isSelected && index != 2
                          ? Theme.of(context).colorScheme.primaryContainer
                          : isSelected
                          ? null
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: index == 2 && !isSelected
                          ? Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.3))
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? _selectedIcons[index] : _icons[index],
                          color: isSelected && index == 2
                              ? Colors.white
                              : index == 2
                              ? const Color(0xFF6C63FF)
                              : isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade500,
                          size: 20,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _labels[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: index == 2 ? 9 : (index == 3 ? 9 : 10),
                            fontWeight: (isSelected || index == 2) ? FontWeight.bold : FontWeight.normal,
                            color: isSelected && index == 2
                                ? Colors.white
                                : index == 2
                                ? const Color(0xFF6C63FF)
                                : isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
