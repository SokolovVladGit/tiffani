import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../catalog/domain/usecases/get_all_brands_use_case.dart';

class TopBrandsState {
  final List<String> brands;
  final bool isLoading;

  const TopBrandsState({this.brands = const [], this.isLoading = false});
}

class TopBrandsCubit extends Cubit<TopBrandsState> {
  final GetAllBrandsUseCase _getAllBrands;

  static const _maxBrands = 10;

  TopBrandsCubit(this._getAllBrands) : super(const TopBrandsState());

  Future<void> load() async {
    emit(const TopBrandsState(isLoading: true));
    try {
      final all = await _getAllBrands();
      emit(TopBrandsState(brands: all.take(_maxBrands).toList()));
    } catch (_) {
      emit(const TopBrandsState());
    }
  }
}
