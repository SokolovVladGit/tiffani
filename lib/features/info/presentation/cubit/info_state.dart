import '../../domain/entities/info_block_entity.dart';

enum InfoStatus { initial, loading, loaded, error }

class InfoState {
  final InfoStatus status;
  final List<InfoBlockEntity> blocks;
  final String? errorMessage;

  const InfoState({
    this.status = InfoStatus.initial,
    this.blocks = const [],
    this.errorMessage,
  });

  InfoState copyWith({
    InfoStatus? status,
    List<InfoBlockEntity>? blocks,
    String? errorMessage,
  }) {
    return InfoState(
      status: status ?? this.status,
      blocks: blocks ?? this.blocks,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
