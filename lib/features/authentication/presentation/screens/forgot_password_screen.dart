import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/state_views.dart';
import '../controllers/auth_form_controllers.dart';
import '../widgets/auth_scaffold.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  String? _sentTo;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final email = _email.text.trim();
    final ok = await ref.read(forgotPasswordControllerProvider.notifier).submit(email);
    if (ok && mounted) setState(() => _sentTo = email);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forgotPasswordControllerProvider);
    final loading = state.isLoading;

    if (_sentTo != null) {
      return AuthScaffold(
        leadingIcon: Icons.mark_email_read_outlined,
        title: 'Check your inbox',
        subtitle:
            'If an account exists for $_sentTo, we sent a link to reset your password. '
            'Open it on this phone to choose a new one.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPrimaryButton(label: 'Back to log in', onPressed: () => context.pop()),
            AppSpacing.gapSm,
            AppSecondaryButton(label: 'Send again', isLoading: loading, onPressed: _submit),
            if (state.failureMessage != null) ...[
              AppSpacing.gapMd,
              FormMessageBanner(message: state.failureMessage!),
            ],
          ],
        ),
      );
    }

    return AuthScaffold(
      title: 'Reset your password',
      subtitle: "Enter your account's email and we'll send you a reset link.",
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
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              prefixIcon: Icons.mail_outline_rounded,
              validator: Validators.email,
              enabled: !loading,
              onFieldSubmitted: (_) => _submit(),
            ),
            AppSpacing.gapLg,
            AppPrimaryButton(label: 'Send reset link', onPressed: _submit, isLoading: loading),
          ],
        ),
      ),
    );
  }
}
