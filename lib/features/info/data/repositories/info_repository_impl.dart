import '../../../../core/services/logger_service.dart';
import '../../domain/entities/info_block_entity.dart';
import '../../domain/repositories/info_repository.dart';
import '../datasources/info_supabase_data_source.dart';
import '../mappers/info_block_mapper.dart';

class InfoRepositoryImpl implements InfoRepository {
  final InfoSupabaseDataSource _dataSource;
  final LoggerService _logger;

  const InfoRepositoryImpl(this._dataSource, this._logger);

  @override
  Future<List<InfoBlockEntity>> getInfoBlocks() async {
    _logger.d('InfoRepositoryImpl.getInfoBlocks');
    final dtos = await _dataSource.getActiveInfoBlocks();
    return dtos.map((d) => d.toEntity()).toList();
  }
}
