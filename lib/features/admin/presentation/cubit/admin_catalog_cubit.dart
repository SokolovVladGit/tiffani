import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/admin_catalog_repository_impl.dart';
import '../../domain/entities/admin_catalog_product.dart';
import '../../domain/entities/admin_native_product_form.dart';
import '../../domain/repositories/admin_catalog_repository.dart';
import 'admin_catalog_state.dart';

class AdminCatalogCubit extends Cubit<AdminCatalogState> {
  AdminCatalogCubit(this._repository) : super(const AdminCatalogState());

  final AdminCatalogRepository _repository;

  Future<void> loadInitial() => _load(searchQuery: state.searchQuery);

  Future<void> refresh() => _load(
        searchQuery: state.searchQuery,
        isRefresh: true,
      );

  Future<void> search(String query) => _load(searchQuery: query);

  Future<AdminNativeProductForm> loadNativeProductForEdit(String productId) async {
    emit(state.copyWith(
      loadingEditProductId: productId,
      clearError: true,
    ));
    try {
      return await _repository.getNativeProductDetail(productId);
    } finally {
      emit(state.copyWith(clearLoadingEditProductId: true));
    }
  }

  Future<bool> saveNativeProduct(AdminNativeProductForm form) async {
    if (state.isSavingNativeProduct) return false;
    emit(state.copyWith(isSavingNativeProduct: true, clearError: true));
    try {
      final result = await _repository.upsertNativeProduct(form);
      _applyUpsertToList(result);
      await refresh();
      return true;
    } catch (e) {
      emit(state.copyWith(errorMessage: _friendlyError(e)));
      return false;
    } finally {
      emit(state.copyWith(isSavingNativeProduct: false));
    }
  }

  void _applyUpsertToList(AdminNativeProductUpsertResult result) {
    final row = AdminCatalogProduct.fromUpsertResult(result);
    final idx = state.products.indexWhere((p) => p.id == result.productId);
    if (idx == -1) {
      final next = [row, ...state.products];
      if (next.length > 50) next.removeRange(50, next.length);
      emit(state.copyWith(products: next, status: AdminCatalogStatus.loaded));
      return;
    }
    final next = List<AdminCatalogProduct>.from(state.products);
    next[idx] = row;
    emit(state.copyWith(products: next, status: AdminCatalogStatus.loaded));
  }

  Future<void> setVisibility(
    String productId,
    bool visible, {
    void Function(String message)? onError,
  }) async {
    if (state.mutatingIds.contains(productId)) return;

    final mutating = Set<String>.from(state.mutatingIds)..add(productId);
    emit(state.copyWith(mutatingIds: mutating));

    try {
      final result = await _repository.setVisibility(
        productId: productId,
        visible: visible,
      );
      _applyVisibilityResult(result);
    } catch (e) {
      onError?.call(_friendlyError(e));
    } finally {
      final cleaned = Set<String>.from(state.mutatingIds)..remove(productId);
      emit(state.copyWith(mutatingIds: cleaned));
    }
  }

  void _applyVisibilityResult(AdminCatalogVisibilityResult result) {
    final idx = state.products.indexWhere((p) => p.id == result.productId);
    if (idx == -1) return;
    final next = List<AdminCatalogProduct>.from(state.products);
    next[idx] = next[idx].copyWith(appIsVisible: result.appIsVisible);
    emit(state.copyWith(
      products: next,
      status: AdminCatalogStatus.loaded,
      clearError: true,
    ));
  }

  Future<void> _load({
    required String searchQuery,
    bool isRefresh = false,
  }) async {
    if (!isRefresh && state.status == AdminCatalogStatus.loading) return;

    emit(state.copyWith(
      status: state.products.isEmpty
          ? AdminCatalogStatus.loading
          : AdminCatalogStatus.loaded,
      searchQuery: searchQuery,
      isRefreshing: isRefresh,
      clearError: true,
    ));

    try {
      final list = await _repository.listProducts(search: searchQuery);
      emit(state.copyWith(
        status: AdminCatalogStatus.loaded,
        products: list,
        isRefreshing: false,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: state.products.isEmpty
            ? AdminCatalogStatus.error
            : AdminCatalogStatus.loaded,
        errorMessage: _friendlyError(e),
        isRefreshing: false,
      ));
    }
  }

  String _friendlyError(Object e) {
    if (e is AdminCatalogException) return e.message;
    final raw = e.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('admin access required')) {
      return 'Недостаточно прав администратора';
    }
    if (lower.contains('row-level security') ||
        lower.contains('permission denied')) {
      return 'Недостаточно прав для этого действия';
    }
    if (lower.contains('tilda products cannot be edited') ||
        lower.contains('tilda product')) {
      return 'Редактирование доступно только для товаров, созданных в приложении';
    }
    if (lower.contains('multi-variant')) {
      return 'Редактирование товара с несколькими вариантами пока не поддерживается';
    }
    if (lower.contains('failedhostlookup') ||
        lower.contains('socketexception')) {
      return 'Нет соединения с сервером';
    }
    return 'Произошла ошибка. Попробуйте позже.';
  }
}
