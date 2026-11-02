import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../routing/routes.dart';
import '../../domain/auth_status.dart';
import '../auth_providers.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authStatusProvider).value;
    final expired = status is Unauthenticated && status.sessionExpired;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: ContentConstraint(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: constraints.maxHeight * 0.12),
                    const AppLogo(),
                    AppSpacing.gapXl,
                    Text(AppConstants.appName, style: context.text.displaySmall),
                    AppSpacing.gapSm,
                    Text(
                      'Plan your workouts, log every set, and see your progress over time.',
                      style: context.text.titleMedium?.copyWith(
                        color: context.tokens.mutedText,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    AppSpacing.gapXl,
                    const _Highlight(icon: Icons.bolt_rounded, text: 'Log a set in one tap'),
                    const _Highlight(
                      icon: Icons.history_rounded,
                      text: 'See what you lifted last time',
                    ),
                    const _Highlight(icon: Icons.cloud_off_rounded, text: 'Works without internet'),
                    SizedBox(height: constraints.maxHeight * 0.08),
                    if (expired) ...[
                      const FormMessageBanner(
                        message: 'Your session has expired. Please log in again.',
                      ),
                      AppSpacing.gapMd,
                    ],
                    AppPrimaryButton(
                      label: 'Create account',
                      onPressed: () => context.push(Routes.register),
                    ),
                    AppSpacing.gapSm,
                    AppSecondaryButton(
                      label: 'Log in',
                      onPressed: () => context.push(Routes.login),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: AppSizes.iconSm + 2, color: context.colors.primary),
          AppSpacing.gapSm,
          Expanded(child: Text(text, style: context.text.bodyLarge)),
        ],
      ),
    );
  }
}
