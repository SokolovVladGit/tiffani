import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/recently_viewed_item.dart';
import '../../domain/repositories/recently_viewed_repository.dart';
import 'recently_viewed_state.dart';

class RecentlyViewedCubit extends Cubit<RecentlyViewedState> {
  final RecentlyViewedRepository _repository;

  RecentlyViewedCubit(this._repository) : super(const RecentlyViewedState());

  Future<void> load() async {
    emit(state.copyWith(isLoading: true));
    try {
      final items = await _repository.getRecentlyViewed();
      emit(state.copyWith(items: items, isLoading: false));
    } catch (_) {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> add(RecentlyViewedItem item) async {
    try {
      await _repository.addItem(item);
      final items = await _repository.getRecentlyViewed();
      emit(state.copyWith(items: items));
    } catch (_) {
      // Non-critical; do not disrupt user flow
    }
  }

  Future<void> clear() async {
    try {
      await _repository.clear();
      emit(state.copyWith(items: []));
    } catch (_) {
      // Non-critical
    }
  }
}
