import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../routing/routes.dart';
import '../controllers/auth_form_controllers.dart';
import '../widgets/auth_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    // On success the router redirects to Home when the auth status changes.
    await ref
        .read(loginControllerProvider.notifier)
        .submit(email: _email.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    final loading = state.isLoading;

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Log in to continue your training.',
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
                validator: Validators.existingPassword,
                textInputAction: TextInputAction.done,
                enabled: !loading,
                onFieldSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: loading ? null : () => context.push(Routes.forgotPassword),
                  child: const Text('Forgot password?'),
                ),
              ),
              AppSpacing.gapSm,
              AppPrimaryButton(label: 'Log in', onPressed: _submit, isLoading: loading),
              AppSpacing.gapMd,
              TextButton(
                onPressed: loading ? null : () => context.pushReplacement(Routes.register),
                child: const Text("Don't have an account? Create one"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
