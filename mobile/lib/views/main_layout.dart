import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../viewmodels/profile_viewmodel.dart';
import 'widgets/custom_bottom_nav_bar.dart';

/// Bottom nav shell. Tabs are role-aware per the mockups:
/// - Homeowner (05): Home / Messages / Profile
/// - Tradie (09): Dashboard / Jobs / Messages / Profile
///
/// Role is read from [profileViewModelProvider] instead of sniffing the URL
/// so a tradie who happens to visit a non-/tradie path still sees the right
/// nav bar.
class MainLayout extends ConsumerWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileViewModelProvider);
    final location = GoRouterState.of(context).uri.path;

    // role == 1 → Tradie. Any other value (0=Homeowner, null, loading) → Homeowner nav.
    // UserRole enum: Homeowner=0, Tradie=1, Admin=2.
    final isTradie = profileState.profile?['role'] == 1;

    if (isTradie) {
      int currentIndex = 0;
      if (location.startsWith('/jobs')) {
        currentIndex = 1;
      } else if (location.startsWith('/messages') ||
          location.startsWith('/chat')) {
        currentIndex = 2;
      } else if (location.startsWith('/profile')) {
        currentIndex = 3;
      }

      return Scaffold(
        extendBody: true,
        body: child,
        bottomNavigationBar: CustomBottomNavBar(
          currentIndex: currentIndex,
          items: const [
            CustomNavBarItem(
                icon: Icons.dashboard_outlined,
                selectedIcon: Icons.dashboard,
                label: 'Dashboard'),
            CustomNavBarItem(
                icon: Icons.work_outline,
                selectedIcon: Icons.work,
                label: 'Jobs'),
            CustomNavBarItem(
                icon: Icons.chat_outlined,
                selectedIcon: Icons.chat,
                label: 'Messages'),
            CustomNavBarItem(
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                label: 'Profile'),
          ],
          onDestinationSelected: (index) {
            switch (index) {
              case 0:
                context.go('/tradie');
              case 1:
                context.go('/jobs');
              case 2:
                context.go('/messages');
              case 3:
                context.go('/profile');
            }
          },
          // Tradies can't post jobs — PostJobScreen redirects them to
          // /tradie, so this is a safe no-op for that role.
          onFabPressed: () => context.push('/jobs/new'),
        ),
      );
    }

    // Homeowner nav.
    int currentIndex = 0;
    if (location.startsWith('/messages') || location.startsWith('/chat')) {
      currentIndex = 1;
    } else if (location.startsWith('/profile')) {
      currentIndex = 2;
    }

    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: currentIndex,
        items: const [
          CustomNavBarItem(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              label: 'Home'),
          CustomNavBarItem(
              icon: Icons.chat_outlined,
              selectedIcon: Icons.chat,
              label: 'Messages'),
          CustomNavBarItem(
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
              label: 'Profile'),
        ],
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/home');
            case 1:
              context.go('/messages');
            case 2:
              context.go('/profile');
          }
        },
        onFabPressed: () => context.push('/jobs/new'),
      ),
    );
  }
}
