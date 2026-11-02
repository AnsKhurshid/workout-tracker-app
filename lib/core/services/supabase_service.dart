import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env_config.dart';
import '../constants/app_constants.dart';
import '../logging/app_logger.dart';

/// Owns Supabase initialisation and is the single access point for the
/// client. Only data-layer classes read [client]; widgets never do.
abstract interface class SupabaseService {
  Future<void> initialize(EnvConfig env);
  SupabaseClient get client;
}

class DefaultSupabaseService implements SupabaseService {
  DefaultSupabaseService(this._logger);

  final AppLogger _logger;
  bool _initialized = false;

  @override
  Future<void> initialize(EnvConfig env) async {
    if (_initialized) return;
    await Supabase.initialize(
      url: env.supabaseUrl.trim(),
      publishableKey: env.supabasePublishableKey.trim(),
      authOptions: const FlutterAuthClientOptions(
        // PKCE: the deep link carries a one-time code instead of tokens.
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
      debug: false,
    );
    _initialized = true;
    _logger.info('Supabase initialised (redirect ${AppConstants.authRedirectUrl})');
  }

  @override
  SupabaseClient get client {
    if (!_initialized) {
      throw StateError('Supabase used before initialisation');
    }
    return Supabase.instance.client;
  }
}
