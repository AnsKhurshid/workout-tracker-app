import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/theme_extensions.dart';

/// App mark: a dumbbell glyph on an accent tile.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Gym Tracker logo',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: context.colors.primary,
          borderRadius: BorderRadius.circular(size * 0.28),
        ),
        child: Icon(
          Icons.fitness_center_rounded,
          size: size * 0.52,
          color: context.colors.onPrimary,
        ),
      ),
    );
  }
}

/// Constrains content width on large screens and adds screen padding.
class ContentConstraint extends StatelessWidget {
  const ContentConstraint({
    super.key,
    required this.child,
    this.padding = AppSpacing.screenPadding,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
