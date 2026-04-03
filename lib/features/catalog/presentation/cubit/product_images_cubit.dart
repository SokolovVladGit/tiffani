import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_product_images_use_case.dart';
import 'product_images_state.dart';

class ProductImagesCubit extends Cubit<ProductImagesState> {
  final GetProductImagesUseCase _getProductImages;

  ProductImagesCubit(this._getProductImages)
      : super(const ProductImagesState());

  Future<void> load(String productId) async {
    emit(state.copyWith(status: ProductImagesStatus.loading));
    try {
      final images = await _getProductImages(productId);
      emit(state.copyWith(
        status: ProductImagesStatus.success,
        images: images,
      ));
    } catch (_) {
      emit(state.copyWith(status: ProductImagesStatus.failure));
    }
  }
}
