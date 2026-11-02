import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_logo.dart';

/// Common layout for the authentication screens: optional back button,
/// heading, scrollable constrained body.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = true,
    this.leadingIcon,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  /// Optional large icon above the title (e.g. an envelope on "check email").
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showBack ? AppBar() : null,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ContentConstraint(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.xs,
              AppSpacing.screenHorizontal,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!showBack) AppSpacing.gapXl,
                if (leadingIcon != null) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: context.colors.primaryContainer,
                        borderRadius: AppRadii.lgAll,
                      ),
                      child: Icon(
                        leadingIcon,
                        size: AppSizes.iconLg,
                        color: context.colors.primary,
                      ),
                    ),
                  ),
                  AppSpacing.gapLg,
                ],
                Text(title, style: context.text.headlineMedium),
                AppSpacing.gapXs,
                Text(
                  subtitle,
                  style: context.text.bodyLarge?.copyWith(color: context.tokens.mutedText),
                ),
                AppSpacing.gapXl,
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
