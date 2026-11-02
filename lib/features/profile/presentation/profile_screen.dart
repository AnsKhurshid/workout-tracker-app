import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/app_theme_preference.dart';
import '../../../models/user_profile.dart';
import '../../../models/weight_unit.dart';
import '../../authentication/presentation/auth_providers.dart';
import '../../authentication/presentation/controllers/auth_form_controllers.dart';
import 'profile_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: profile.when(
          loading: () => const _ProfileSkeleton(),
          error: (e, _) => ErrorView(
            title: "Couldn't load your profile",
            message: mapError(e).userMessage,
            onRetry: () => ref.invalidate(currentProfileProvider),
          ),
          data: (data) => data == null
              ? const _ProfileSkeleton()
              : ListView(
                  padding: AppSpacing.screenPadding,
                  children: [
                    _ProfileHeader(profile: data, email: user?.email ?? ''),
                    AppSpacing.gapLg,
                    _PreferencesSection(profile: data),
                    AppSpacing.gapMd,
                    const _AccountSection(),
                    AppSpacing.gapXl,
                  ],
                ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.profile, required this.email});

  final UserProfile profile;
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = profile.displayName;
    final hasName = name != null && name.isNotEmpty;
    final initial = (hasName ? name : email).characters.firstOrNull?.toUpperCase() ?? '?';
    final pending = ref.watch(profileHasPendingChangesProvider).value ?? false;

    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: context.colors.primaryContainer,
          child: Text(
            initial,
            style: context.text.headlineSmall?.copyWith(color: context.colors.primary),
          ),
        ),
        AppSpacing.gapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasName ? name : 'Add your name',
                style: context.text.titleLarge?.copyWith(
                  color: hasName ? null : context.tokens.mutedText,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              AppSpacing.gapXxs,
              Text(
                email,
                style: context.text.bodyMedium?.copyWith(color: context.tokens.mutedText),
                overflow: TextOverflow.ellipsis,
              ),
              if (pending) ...[
                AppSpacing.gapXxs,
                Row(
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 14, color: context.tokens.warning),
                    AppSpacing.gapXxs,
                    Text(
                      'Saved on this device, waiting to sync',
                      style: context.text.labelSmall?.copyWith(color: context.tokens.warning),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        IconButton(
          tooltip: 'Edit name',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => _editName(context, ref, name ?? ''),
        ),
      ],
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref, String current) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _EditNameDialog(initial: current),
    );
    if (name == null || !context.mounted) return;
    final error = await ref.read(profileActionsProvider).setDisplayName(name);
    if (context.mounted && error != null) showAppSnackBar(context, error, isError: true);
  }
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.initial});

  final String initial;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Display name'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLength: AppConstants.displayNameMaxLength,
          textCapitalization: TextCapitalization.words,
          validator: Validators.displayName,
          onFieldSubmitted: (_) => _save(),
          decoration: const InputDecoration(labelText: 'Name'),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _PreferencesSection extends ConsumerWidget {
  const _PreferencesSection({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themePreferenceProvider).value ?? AppThemePreference.defaultValue;

    return SectionCard(
      title: 'Preferences',
      icon: Icons.tune_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SettingLabel(
            title: 'Weight unit',
            subtitle: 'Used for logging and displaying weights. Your history is kept as recorded.',
          ),
          AppSpacing.gapSm,
          SegmentedButton<WeightUnit>(
            showSelectedIcon: false,
            segments: [
              for (final unit in WeightUnit.values)
                ButtonSegment(value: unit, label: Text(unit.label)),
            ],
            selected: {profile.weightUnit},
            onSelectionChanged: (selection) async {
              final error = await ref.read(profileActionsProvider).setWeightUnit(selection.first);
              if (context.mounted && error != null) {
                showAppSnackBar(context, error, isError: true);
              }
            },
          ),
          AppSpacing.gapLg,
          const _SettingLabel(title: 'Theme', subtitle: 'Applies to this device.'),
          AppSpacing.gapSm,
          SegmentedButton<AppThemePreference>(
            showSelectedIcon: false,
            segments: [
              for (final option in AppThemePreference.values)
                ButtonSegment(value: option, label: Text(option.label)),
            ],
            selected: {theme},
            onSelectionChanged: (selection) async {
              try {
                await ref.read(appSettingsRepositoryProvider).setThemePreference(selection.first);
              } catch (e) {
                if (context.mounted) {
                  showAppSnackBar(context, mapError(e).userMessage, isError: true);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

class _SettingLabel extends StatelessWidget {
  const _SettingLabel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
        AppSpacing.gapXxs,
        Text(subtitle, style: context.text.bodySmall),
      ],
    );
  }
}

class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signOut = ref.watch(signOutControllerProvider);
    return SectionCard(
      title: 'Account',
      icon: Icons.manage_accounts_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your data stays on this device when you log out and syncs again when you log back in.',
            style: context.text.bodySmall,
          ),
          AppSpacing.gapMd,
          if (signOut.failureMessage != null) ...[
            FormMessageBanner(message: signOut.failureMessage!),
            AppSpacing.gapSm,
          ],
          AppSecondaryButton(
            label: 'Log out',
            icon: Icons.logout_rounded,
            isLoading: signOut.isLoading,
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: 'Log out?',
                message: 'You can log back in at any time.',
                confirmLabel: 'Log out',
              );
              if (confirmed) await ref.read(signOutControllerProvider.notifier).signOut();
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        children: [
          Row(
            children: [
              SkeletonBox(width: 64, height: 64, radius: 32),
              AppSpacing.gapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 160, height: 20),
                    AppSpacing.gapXs,
                    SkeletonBox(width: 200, height: 14),
                  ],
                ),
              ),
            ],
          ),
          AppSpacing.gapLg,
          SkeletonBox(height: 220, radius: AppRadii.lg),
        ],
      ),
    );
  }
}
