import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/planned_feature_view.dart';

/// Placeholder until history and analytics (Phase 5).
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: PlannedFeatureView(
            icon: Icons.insights_rounded,
            title: 'No progress to show yet',
            message: 'Once you start logging workouts, your progress for each exercise will appear here.',
            upcoming: [
              'Weight and repetition progression charts',
              'Training volume over time',
              'Estimated one-rep max (Epley formula)',
              'Estimated personal records',
            ],
          ),
        ),
      ),
    );
  }
}
