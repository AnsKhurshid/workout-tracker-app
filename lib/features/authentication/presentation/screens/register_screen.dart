import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../routing/routes.dart';
import '../../domain/auth_repository.dart';
import '../controllers/auth_form_controllers.dart';
import '../widgets/auth_scaffold.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final email = _email.text.trim();
    final outcome = await ref
        .read(registerControllerProvider.notifier)
        .submit(displayName: _name.text, email: email, password: _password.text);
    if (!mounted) return;
    if (outcome == SignUpOutcome.confirmationRequired) {
      context.go(Uri(path: Routes.checkEmail, queryParameters: {'email': email}).toString());
    }
    // SignUpOutcome.signedIn: the router redirects to Home on its own.
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registerControllerProvider);
    final loading = state.isLoading;

    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Your plans and workout history are saved to your account.',
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
              AppTextField(
                controller: _name,
                label: 'Display name',
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                prefixIcon: Icons.person_outline_rounded,
                maxLength: AppConstants.displayNameMaxLength,
                validator: Validators.displayName,
                enabled: !loading,
              ),
              AppSpacing.gapMd,
              AppTextField(
                controller: _email,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                prefixIcon: Icons.mail_outline_rounded,
                validator: Validators.email,
                enabled: !loading,
              ),
              AppSpacing.gapMd,
              AppPasswordField(
                controller: _password,
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
                label: 'Confirm password',
                isNewPassword: true,
                validator: Validators.confirmPassword(() => _password.text),
                textInputAction: TextInputAction.done,
                enabled: !loading,
                onFieldSubmitted: (_) => _submit(),
              ),
              AppSpacing.gapLg,
              AppPrimaryButton(label: 'Create account', onPressed: _submit, isLoading: loading),
              AppSpacing.gapMd,
              TextButton(
                onPressed: loading ? null : () => context.pushReplacement(Routes.login),
                child: const Text('Already have an account? Log in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
