import '../entities/info_block_entity.dart';

abstract interface class InfoRepository {
  Future<List<InfoBlockEntity>> getInfoBlocks();
}
