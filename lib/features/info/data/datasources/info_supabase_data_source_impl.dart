import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/logger_service.dart';
import '../dto/info_block_dto.dart';
import 'info_supabase_data_source.dart';

class InfoSupabaseDataSourceImpl implements InfoSupabaseDataSource {
  final SupabaseClient _client;
  final LoggerService _logger;

  static const _table = 'info_blocks';

  const InfoSupabaseDataSourceImpl(this._client, this._logger);

  @override
  Future<List<InfoBlockDto>> getActiveInfoBlocks() async {
    _logger.d('getActiveInfoBlocks');
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      _logger.d('getActiveInfoBlocks raw: ${response.length} rows');
      final blocks = <InfoBlockDto>[];
      for (int i = 0; i < response.length; i++) {
        try {
          blocks.add(InfoBlockDto.fromMap(response[i]));
        } catch (e) {
          // Soft-skip a malformed row so the rest of the page still renders.
          // Surface as a warning so it remains visible in dev logs.
          _logger.w('InfoBlockDto.fromMap failed on row $i: $e');
        }
      }
      _logger.d('getActiveInfoBlocks parsed: ${blocks.length} blocks');
      return blocks;
    } catch (e) {
      _logger.e('getActiveInfoBlocks failed: $e');
      rethrow;
    }
  }
}
