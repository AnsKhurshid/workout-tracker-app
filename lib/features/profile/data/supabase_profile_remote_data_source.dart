import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile_remote_data_source.dart';

class SupabaseProfileRemoteDataSource implements ProfileRemoteDataSource {
  SupabaseProfileRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _timeout = Duration(seconds: 15);

  @override
  Future<RemoteProfile?> fetch(String userId) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle()
        .timeout(_timeout);
    return row == null ? null : RemoteProfile.fromJson(row);
  }

  @override
  Future<void> upsert(RemoteProfile profile) async {
    await _client.from('profiles').upsert(profile.toUpsertJson()).timeout(_timeout);
  }
}
