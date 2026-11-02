import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/theme_extensions.dart';

/// Explains that there is nothing here yet, with an optional next step.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  /// Smaller layout for use inside a card.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? AppSizes.iconLg : AppSizes.emptyStateIcon;
    return Padding(
      padding: EdgeInsets.all(compact ? AppSpacing.xs : AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: iconSize, color: context.colors.onSurfaceVariant),
          ),
          SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: compact ? context.text.titleMedium : context.text.titleLarge,
          ),
          AppSpacing.gapXs,
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: context.tokens.mutedText),
          ),
          if (action != null) ...[
            SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}

/// A failure with an optional retry.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.title = 'Something went wrong',
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: EmptyState(
        icon: Icons.error_outline_rounded,
        title: title,
        message: message,
        action: onRetry == null
            ? null
            : OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
      ),
    );
  }
}

/// Centered spinner for full-screen loading.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (label != null) ...[AppSpacing.gapMd, Text(label!, style: context.text.bodyMedium)],
        ],
      ),
    );
  }
}

/// Static placeholder block shown while content loads. Deliberately not
/// animated (see the design guidelines on avoiding unnecessary motion).
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = AppRadii.sm});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: context.tokens.skeleton,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Inline error message for forms (e.g. "Incorrect email or password").
class FormMessageBanner extends StatelessWidget {
  const FormMessageBanner({super.key, required this.message, this.isError = true});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final background = isError ? colors.errorContainer : colors.primaryContainer;
    final foreground = isError ? colors.onErrorContainer : colors.onPrimaryContainer;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(color: background, borderRadius: AppRadii.mdAll),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: foreground,
              size: AppSizes.iconSm + 2,
            ),
            AppSpacing.gapXs,
            Expanded(
              child: Text(message, style: context.text.bodyMedium?.copyWith(color: foreground)),
            ),
          ],
        ),
      ),
    );
  }
}
