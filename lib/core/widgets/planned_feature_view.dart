import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/theme_extensions.dart';
import 'state_views.dart';

/// Honest placeholder for a section that is not built yet. It never shows
/// sample data; it says what will appear here.
class PlannedFeatureView extends StatelessWidget {
  const PlannedFeatureView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.upcoming = const [],
  });

  final IconData icon;
  final String title;
  final String message;

  /// Short list of what this section will offer.
  final List<String> upcoming;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        EmptyState(icon: icon, title: title, message: message),
        if (upcoming.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.construction_rounded,
                        size: AppSizes.iconSm,
                        color: context.tokens.warning,
                      ),
                      AppSpacing.gapXs,
                      Text('In development', style: context.text.labelLarge),
                    ],
                  ),
                  AppSpacing.gapSm,
                  for (final item in upcoming)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: context.colors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          AppSpacing.gapSm,
                          Expanded(child: Text(item, style: context.text.bodyMedium)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
