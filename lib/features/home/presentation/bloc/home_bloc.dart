import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_home_hit_items_use_case.dart';
import '../../domain/usecases/get_home_new_items_use_case.dart';
import '../../domain/usecases/get_home_sale_items_use_case.dart';
import '../home_strings.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetHomeNewItemsUseCase _getNewItems;
  final GetHomeSaleItemsUseCase _getSaleItems;
  final GetHomeHitItemsUseCase _getHitItems;

  HomeBloc(
    this._getNewItems,
    this._getSaleItems,
    this._getHitItems,
  ) : super(const HomeState()) {
    on<HomeStarted>(_onStarted);
    on<HomeRefreshed>(_onRefreshed);
  }

  Future<void> _onStarted(
    HomeStarted event,
    Emitter<HomeState> emit,
  ) async {
    await _loadSections(emit);
  }

  Future<void> _onRefreshed(
    HomeRefreshed event,
    Emitter<HomeState> emit,
  ) async {
    await _loadSections(emit);
  }

  Future<void> _loadSections(Emitter<HomeState> emit) async {
    emit(state.copyWith(status: HomeStatus.loading));
    try {
      final products = await Future.wait([
        _getNewItems(),
        _getSaleItems(),
        _getHitItems(),
      ]);

      emit(state.copyWith(
        status: HomeStatus.success,
        newItems: products[0],
        saleItems: products[1],
        hitItems: products[2],
        errorMessage: null,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: HomeStatus.failure,
        errorMessage: HomeStrings.loadError,
      ));
    }
  }
}
