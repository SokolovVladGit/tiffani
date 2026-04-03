import '../dto/info_block_dto.dart';

abstract interface class InfoSupabaseDataSource {
  Future<List<InfoBlockDto>> getActiveInfoBlocks();
}
