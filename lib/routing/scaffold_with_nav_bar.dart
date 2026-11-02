import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The authenticated shell: bottom navigation with four tabs. Each tab keeps
/// its own navigation stack and state (`StatefulShellRoute.indexedStack`).
class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home_rounded),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.fitness_center_outlined),
      selectedIcon: Icon(Icons.fitness_center_rounded),
      label: 'Workouts',
    ),
    NavigationDestination(
      icon: Icon(Icons.insights_outlined),
      selectedIcon: Icon(Icons.insights_rounded),
      label: 'Progress',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).dividerTheme.color!)),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          destinations: destinations,
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            // Tapping the current tab again returns to its first page.
            initialLocation: index == navigationShell.currentIndex,
          ),
        ),
      ),
    );
  }
}
