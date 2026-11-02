import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../routing/routes.dart';
import '../widgets/auth_scaffold.dart';

/// Shown after sign-up when the Supabase project requires email confirmation.
class CheckEmailScreen extends StatelessWidget {
  const CheckEmailScreen({super.key, this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    final target = (email == null || email!.isEmpty) ? 'your email address' : email!;
    return AuthScaffold(
      showBack: false,
      leadingIcon: Icons.mark_email_unread_outlined,
      title: 'Confirm your email',
      subtitle:
          'We sent a confirmation link to $target. Open it on this phone to activate your account, then log in.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPrimaryButton(label: 'Go to log in', onPressed: () => context.go(Routes.login)),
          AppSpacing.gapSm,
          AppSecondaryButton(
            label: 'Use a different email',
            onPressed: () => context.go(Routes.register),
          ),
          AppSpacing.gapLg,
          Text(
            "Can't find it? Check your spam folder. The link expires after a while; "
            'if it does, sign up again with the same email to get a new one.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
