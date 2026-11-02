import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/authentication/domain/auth_repository.dart';
import '../features/authentication/presentation/auth_providers.dart';
import '../features/authentication/presentation/screens/check_email_screen.dart';
import '../features/authentication/presentation/screens/forgot_password_screen.dart';
import '../features/authentication/presentation/screens/login_screen.dart';
import '../features/authentication/presentation/screens/register_screen.dart';
import '../features/authentication/presentation/screens/reset_password_screen.dart';
import '../features/authentication/presentation/screens/welcome_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/progress/presentation/progress_screen.dart';
import '../features/workout_plans/presentation/workouts_screen.dart';
import 'auth_redirect.dart';
import 'routes.dart';
import 'scaffold_with_nav_bar.dart';

/// Re-runs the router's redirect whenever the auth status changes, without
/// rebuilding the router or any widgets.
class AuthRefreshListenable extends ChangeNotifier {
  AuthRefreshListenable(AuthRepository repository) {
    _subscription = repository.statusChanges().listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Created once per app session (after startup); never rebuilt on auth changes.
final appRouterProvider = Provider<GoRouter>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final refresh = AuthRefreshListenable(repository);
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.home,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refresh,
    redirect: (context, state) => authRedirect(repository.currentStatus, state.uri.toString()),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => Routes.home),
      GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: Routes.register,
        builder: (_, _) => const RegisterScreen(),
        routes: [
          GoRoute(
            path: 'check-email',
            builder: (_, state) => CheckEmailScreen(email: state.uri.queryParameters['email']),
          ),
        ],
      ),
      GoRoute(path: Routes.forgotPassword, builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(path: Routes.resetPassword, builder: (_, _) => const ResetPasswordScreen()),
      // The deep link host (`.../auth-callback?code=...`) is consumed by
      // Supabase; if the router sees it, route to the right place.
      GoRoute(path: '/auth-callback', redirect: (_, _) => Routes.home),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ScaffoldWithNavBar(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.workouts, builder: (_, _) => const WorkoutsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.progress, builder: (_, _) => const ProgressScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen())],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => _NotFoundScreen(location: state.uri.path),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Page not found', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(location, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(onPressed: () => context.go(Routes.home), child: const Text('Go home')),
            ],
          ),
        ),
      ),
    );
  }
}
