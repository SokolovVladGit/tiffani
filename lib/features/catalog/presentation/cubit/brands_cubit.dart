import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_all_brands_use_case.dart';

class BrandsState {
  final List<String> brands;
  final bool isLoading;
  final String? errorMessage;

  const BrandsState({
    this.brands = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  BrandsState copyWith({
    List<String>? brands,
    bool? isLoading,
    String? errorMessage,
  }) {
    return BrandsState(
      brands: brands ?? this.brands,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class BrandsCubit extends Cubit<BrandsState> {
  final GetAllBrandsUseCase _getAllBrands;

  BrandsCubit(this._getAllBrands) : super(const BrandsState());

  Future<void> loadBrands() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final brands = await _getAllBrands();
      emit(state.copyWith(brands: brands, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: '$e'));
    }
  }
}
