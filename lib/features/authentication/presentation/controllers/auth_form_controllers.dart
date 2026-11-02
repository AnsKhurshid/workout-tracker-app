import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../domain/auth_repository.dart';
import '../auth_providers.dart';

/// Shared behaviour for auth forms: one submission at a time, loading state,
/// and errors converted to [AppFailure] for display.
///
/// State is `AsyncData(null)` when idle or done, `AsyncLoading` while
/// submitting, and `AsyncError(AppFailure)` after a failure.
abstract class _SubmitController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  AuthRepository get repository => ref.read(authRepositoryProvider);

  bool get isSubmitting => state.isLoading;

  /// Runs [action]; returns its result, or null if it failed.
  Future<T?> run<T>(Future<T> Function() action) async {
    if (state.isLoading) return null;
    state = const AsyncLoading();
    try {
      final result = await action();
      if (ref.mounted) state = const AsyncData(null);
      return result;
    } catch (e, st) {
      if (ref.mounted) state = AsyncError(mapError(e), st);
      return null;
    }
  }

  void clearError() {
    if (state.hasError) state = const AsyncData(null);
  }
}

/// The user-facing message of the last failure, if any.
extension SubmitStateMessage on AsyncValue<void> {
  String? get failureMessage {
    final error = this.error;
    if (error == null) return null;
    return error is AppFailure ? error.userMessage : mapError(error).userMessage;
  }
}

class LoginController extends _SubmitController {
  Future<bool> submit({required String email, required String password}) async =>
      await run(() async {
        await repository.signIn(email: email, password: password);
        return true;
      }) ??
      false;
}

final loginControllerProvider = NotifierProvider.autoDispose<LoginController, AsyncValue<void>>(
  LoginController.new,
);

class RegisterController extends _SubmitController {
  Future<SignUpOutcome?> submit({
    required String displayName,
    required String email,
    required String password,
  }) => run(() => repository.signUp(displayName: displayName, email: email, password: password));
}

final registerControllerProvider =
    NotifierProvider.autoDispose<RegisterController, AsyncValue<void>>(RegisterController.new);

class ForgotPasswordController extends _SubmitController {
  Future<bool> submit(String email) async =>
      await run(() async {
        await repository.sendPasswordResetEmail(email);
        return true;
      }) ??
      false;
}

final forgotPasswordControllerProvider =
    NotifierProvider.autoDispose<ForgotPasswordController, AsyncValue<void>>(
      ForgotPasswordController.new,
    );

class ResetPasswordController extends _SubmitController {
  Future<bool> submit(String newPassword) async =>
      await run(() async {
        await repository.updatePassword(newPassword);
        return true;
      }) ??
      false;

  Future<void> cancel() => run(repository.signOut);
}

final resetPasswordControllerProvider =
    NotifierProvider.autoDispose<ResetPasswordController, AsyncValue<void>>(
      ResetPasswordController.new,
    );

class SignOutController extends _SubmitController {
  Future<bool> signOut() async =>
      await run(() async {
        await repository.signOut();
        return true;
      }) ??
      false;
}

final signOutControllerProvider = NotifierProvider.autoDispose<SignOutController, AsyncValue<void>>(
  SignOutController.new,
);
