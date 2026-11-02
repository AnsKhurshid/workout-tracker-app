import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/planned_feature_view.dart';

/// Placeholder until workout plans and the exercise library (Phase 3).
class WorkoutsScreen extends StatelessWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workouts')),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: PlannedFeatureView(
            icon: Icons.fitness_center_rounded,
            title: 'No workout plans yet',
            message:
                'Workout plans and the exercise library are being built and will appear here soon.',
            upcoming: [
              'Create plans like Push Day, Pull Day or Full Body',
              'Add exercises with default sets, reps, weight and rest time',
              'Browse and search the exercise library, or add your own',
              'Duplicate, reorder and activate or deactivate plans',
            ],
          ),
        ),
      ),
    );
  }
}
