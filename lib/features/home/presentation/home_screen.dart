import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../routing/routes.dart';
import '../../authentication/presentation/auth_providers.dart';
import '../../profile/presentation/profile_providers.dart';

/// Dashboard. Workout data does not exist yet (Phases 3 to 5), so every
/// section shows an honest empty state instead of sample numbers.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            const _Greeting(),
            AppSpacing.gapLg,
            SectionCard(
              title: "Today's workout",
              icon: Icons.today_rounded,
              child: EmptyState(
                compact: true,
                icon: Icons.event_note_outlined,
                title: 'No workouts yet',
                message: 'Create your first workout plan to get started.',
                action: OutlinedButton.icon(
                  onPressed: () => context.go(Routes.workouts),
                  icon: const Icon(Icons.fitness_center_rounded),
                  label: const Text('Go to Workouts'),
                ),
              ),
            ),
            AppSpacing.gapMd,
            SectionCard(
              title: 'Quick start',
              icon: Icons.bolt_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Start an empty workout and add exercises as you go.',
                    style: context.text.bodyMedium,
                  ),
                  AppSpacing.gapMd,
                  const FilledButton(onPressed: null, child: Text('Start empty workout')),
                  AppSpacing.gapXs,
                  Text(
                    'Workout logging is coming in an upcoming update.',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            AppSpacing.gapMd,
            const SectionCard(
              title: 'This week',
              icon: Icons.calendar_view_week_rounded,
              child: EmptyState(
                compact: true,
                icon: Icons.bar_chart_rounded,
                title: 'No activity this week',
                message: 'Your workouts and completed sets for the week will show here.',
              ),
            ),
            AppSpacing.gapMd,
            const SectionCard(
              title: 'Recent activity',
              icon: Icons.history_rounded,
              child: EmptyState(
                compact: true,
                icon: Icons.history_toggle_off_rounded,
                title: 'Nothing logged yet',
                message: 'Your completed workouts will appear here.',
              ),
            ),
            AppSpacing.gapXl,
          ],
        ),
      ),
    );
  }
}

class _Greeting extends ConsumerWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final user = ref.watch(currentUserProvider);
    final name = profile.value?.displayName ?? user?.displayName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _dateLabel(DateTime.now()),
          style: context.text.labelMedium?.copyWith(color: context.tokens.mutedText),
        ),
        AppSpacing.gapXxs,
        if (profile.isLoading && name == null)
          const SkeletonBox(width: 220, height: 32)
        else
          Text(
            name == null || name.isEmpty ? 'Welcome back' : 'Welcome back, $name',
            style: context.text.headlineMedium,
          ),
      ],
    );
  }

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String _dateLabel(DateTime date) =>
      '${_weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]}';
}
