import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/info_repository.dart';
import 'info_state.dart';

class InfoCubit extends Cubit<InfoState> {
  final InfoRepository _repository;

  InfoCubit(this._repository) : super(const InfoState());

  Future<void> load() async {
    emit(state.copyWith(status: InfoStatus.loading));
    try {
      final blocks = await _repository.getInfoBlocks();
      emit(state.copyWith(status: InfoStatus.loaded, blocks: blocks));
    } catch (e, stackTrace) {
      debugPrint('InfoCubit.load failed: $e\n$stackTrace');
      emit(state.copyWith(
        status: InfoStatus.error,
        errorMessage: 'Не удалось загрузить информацию',
      ));
    }
  }
}
