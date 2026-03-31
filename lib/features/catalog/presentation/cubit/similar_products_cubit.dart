import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_similar_products_use_case.dart';
import 'similar_products_state.dart';

class SimilarProductsCubit extends Cubit<SimilarProductsState> {
  final GetSimilarProductsUseCase _getSimilarProducts;

  SimilarProductsCubit(this._getSimilarProducts)
      : super(const SimilarProductsState());

  Future<void> load({
    required String excludeId,
    String? brand,
    String? category,
  }) async {
    emit(state.copyWith(status: SimilarProductsStatus.loading));
    try {
      final items = await _getSimilarProducts(
        excludeId: excludeId,
        brand: brand,
        category: category,
      );
      emit(state.copyWith(
        status: SimilarProductsStatus.success,
        items: items,
      ));
    } catch (_) {
      emit(state.copyWith(status: SimilarProductsStatus.failure));
    }
  }
}
