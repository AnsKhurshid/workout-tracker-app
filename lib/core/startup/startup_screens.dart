import 'package:flutter/material.dart';

import '../errors/app_failure.dart';
import '../theme/app_spacing.dart';
import '../theme/theme_extensions.dart';
import '../widgets/app_logo.dart';
import '../widgets/state_views.dart';

/// Shown while startup work runs.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogo(size: 64),
            AppSpacing.gapLg,
            SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
          ],
        ),
      ),
    );
  }
}

/// Shown when startup fails. Configuration problems get developer-oriented
/// instructions; other failures get a retry.
class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({super.key, required this.failure, required this.onRetry});

  final AppFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = this.failure;
    return Scaffold(
      body: SafeArea(
        child: failure is ConfigurationFailure
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSpacing.gapXl,
                    Icon(
                      Icons.settings_suggest_outlined,
                      size: AppSizes.emptyStateIcon,
                      color: context.tokens.warning,
                    ),
                    AppSpacing.gapMd,
                    Text('Configuration required', style: context.text.headlineSmall),
                    AppSpacing.gapSm,
                    Text(
                      'This build was started without its Supabase settings. '
                      'Create a .env file from .env.example and run:',
                      style: context.text.bodyMedium,
                    ),
                    AppSpacing.gapSm,
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceContainerHigh,
                        borderRadius: AppRadii.mdAll,
                      ),
                      child: SelectableText(
                        'flutter run --dart-define-from-file=.env',
                        style: context.text.bodyMedium?.copyWith(fontFamily: 'monospace'),
                      ),
                    ),
                    AppSpacing.gapMd,
                    Text('Problems found:', style: context.text.titleSmall),
                    AppSpacing.gapXs,
                    for (final problem in failure.problems)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                        child: Text('• $problem', style: context.text.bodyMedium),
                      ),
                    AppSpacing.gapMd,
                    Text('See ENVIRONMENT_SETUP.md for details.', style: context.text.bodySmall),
                  ],
                ),
              )
            : ErrorView(
                title: failure is StorageFailure
                    ? "Couldn't open your data"
                    : "Couldn't start the app",
                message: failure.userMessage,
                onRetry: onRetry,
              ),
      ),
    );
  }
}
