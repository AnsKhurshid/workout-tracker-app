import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/errors/error_mapper.dart';
import 'core/providers.dart';
import 'core/startup/app_startup.dart';
import 'core/startup/startup_screens.dart';
import 'core/theme/app_theme.dart';
import 'models/app_theme_preference.dart';
import 'routing/app_router.dart';

/// Root widget. Shows a splash while [appStartupProvider] runs, an error
/// screen if it fails, and the routed app once it succeeds.
class GymTrackerApp extends ConsumerWidget {
  const GymTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(appStartupProvider);
    return startup.when(
      data: (_) => const _RoutedApp(),
      loading: () => _shell(const SplashScreen()),
      error: (e, _) => _shell(
        StartupErrorScreen(failure: mapError(e), onRetry: () => ref.invalidate(appStartupProvider)),
      ),
    );
  }

  /// Startup screens always use the dark theme: the stored preference lives
  /// in the database, which may not be open yet.
  Widget _shell(Widget home) => MaterialApp(
    title: AppConstants.appName,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark(),
    home: home,
  );
}

class _RoutedApp extends ConsumerWidget {
  const _RoutedApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final preference = ref.watch(themePreferenceProvider).value ?? AppThemePreference.defaultValue;
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: preference.themeMode,
      routerConfig: router,
    );
  }
}
