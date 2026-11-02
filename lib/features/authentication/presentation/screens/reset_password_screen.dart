import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/state_views.dart';
import '../controllers/auth_form_controllers.dart';
import '../widgets/auth_scaffold.dart';

/// Reached from the password reset email link (the router sends the user here
/// while the auth status is `PasswordRecovery`).
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(resetPasswordControllerProvider.notifier).submit(_password.text);
    if (ok) {
      // The router moves to Home; the messenger outlives this screen.
      messenger.showSnackBar(const SnackBar(content: Text('Your password has been updated.')));
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cancel password reset?',
      message: "You'll be logged out. You can request a new reset link at any time.",
      confirmLabel: 'Log out',
      cancelLabel: 'Keep going',
    );
    if (confirmed) await ref.read(resetPasswordControllerProvider.notifier).cancel();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resetPasswordControllerProvider);
    final loading = state.isLoading;

    return AuthScaffold(
      showBack: false,
      leadingIcon: Icons.lock_reset_rounded,
      title: 'Choose a new password',
      subtitle: 'Enter a new password for your account.',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.failureMessage != null) ...[
                FormMessageBanner(message: state.failureMessage!),
                AppSpacing.gapMd,
              ],
              AppPasswordField(
                controller: _password,
                label: 'New password',
                isNewPassword: true,
                helperText:
                    'At least ${AppConstants.passwordMinLength} characters, with a letter and a number.',
                validator: Validators.newPassword,
                textInputAction: TextInputAction.next,
                enabled: !loading,
              ),
              AppSpacing.gapMd,
              AppPasswordField(
                controller: _confirm,
                label: 'Confirm new password',
                isNewPassword: true,
                validator: Validators.confirmPassword(() => _password.text),
                textInputAction: TextInputAction.done,
                enabled: !loading,
                onFieldSubmitted: (_) => _submit(),
              ),
              AppSpacing.gapLg,
              AppPrimaryButton(label: 'Update password', onPressed: _submit, isLoading: loading),
              AppSpacing.gapSm,
              TextButton(onPressed: loading ? null : _cancel, child: const Text('Cancel')),
            ],
          ),
        ),
      ),
    );
  }
}
