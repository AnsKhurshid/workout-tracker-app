import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/theme_extensions.dart';

/// A titled card used to group content on a screen. Avoid nesting cards
/// inside it; use dividers or spacing instead.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: AppSizes.iconSm, color: context.colors.primary),
                    AppSpacing.gapXs,
                  ],
                  Expanded(child: Text(title!, style: context.text.titleMedium)),
                  ?trailing,
                ],
              ),
              AppSpacing.gapSm,
            ],
            child,
          ],
        ),
      ),
    );
  }
}
