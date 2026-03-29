import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_delivery_rules_use_case.dart';
import '../../domain/usecases/get_stores_use_case.dart';
import 'stores_delivery_event.dart';
import 'stores_delivery_state.dart';

class StoresDeliveryBloc
    extends Bloc<StoresDeliveryEvent, StoresDeliveryState> {
  final GetStoresUseCase _getStores;
  final GetDeliveryRulesUseCase _getDeliveryRules;

  StoresDeliveryBloc(this._getStores, this._getDeliveryRules)
      : super(const StoresDeliveryState()) {
    on<StoresDeliveryStarted>(_onStarted);
    on<StoresDeliveryRefreshed>(_onRefreshed);
  }

  Future<void> _onStarted(
    StoresDeliveryStarted event,
    Emitter<StoresDeliveryState> emit,
  ) async {
    await _load(emit);
  }

  Future<void> _onRefreshed(
    StoresDeliveryRefreshed event,
    Emitter<StoresDeliveryState> emit,
  ) async {
    await _load(emit);
  }

  Future<void> _load(Emitter<StoresDeliveryState> emit) async {
    emit(state.copyWith(status: StoresDeliveryStatus.loading));
    try {
      final (stores, rules) = await (
        _getStores(),
        _getDeliveryRules(),
      ).wait;
      emit(state.copyWith(
        status: StoresDeliveryStatus.success,
        stores: stores,
        deliveryRules: rules,
        errorMessage: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: StoresDeliveryStatus.failure,
        errorMessage: '$e',
      ));
    }
  }
}
