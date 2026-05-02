import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/logger_service.dart';
import '../../domain/repositories/admin_access_repository.dart';

class AdminAccessRepositoryImpl implements AdminAccessRepository {
  final SupabaseClient _client;
  final LoggerService _logger;

  const AdminAccessRepositoryImpl(this._client, this._logger);

  @override
  Future<bool> isAdmin() async {
    if (_client.auth.currentUser == null) return false;
    try {
      final dynamic result = await _client.rpc('is_admin');
      if (result is bool) return result;
      if (result is num) return result != 0;
      if (result is String) {
        final v = result.toLowerCase();
        return v == 'true' || v == 't' || v == '1';
      }
      _logger.w('is_admin RPC returned unexpected type: ${result.runtimeType}');
      return false;
    } catch (e) {
      _logger.w('is_admin RPC failed: $e');
      return false;
    }
  }
}
