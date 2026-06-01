import '../../domain/entities/admin_catalog_product.dart';

enum AdminCatalogStatus { idle, loading, loaded, error }

class AdminCatalogState {
  final AdminCatalogStatus status;
  final List<AdminCatalogProduct> products;
  final String searchQuery;
  final String? errorMessage;
  final Set<String> mutatingIds;
  final bool isRefreshing;
  final bool isSavingNativeProduct;
  final String? loadingEditProductId;

  const AdminCatalogState({
    this.status = AdminCatalogStatus.idle,
    this.products = const [],
    this.searchQuery = '',
    this.errorMessage,
    this.mutatingIds = const {},
    this.isRefreshing = false,
    this.isSavingNativeProduct = false,
    this.loadingEditProductId,
  });

  bool get isLoading =>
      status == AdminCatalogStatus.loading && products.isEmpty;

  bool get isEmptyLoaded =>
      status == AdminCatalogStatus.loaded && products.isEmpty;

  AdminCatalogState copyWith({
    AdminCatalogStatus? status,
    List<AdminCatalogProduct>? products,
    String? searchQuery,
    String? errorMessage,
    Set<String>? mutatingIds,
    bool? isRefreshing,
    bool? isSavingNativeProduct,
    String? loadingEditProductId,
    bool clearError = false,
    bool clearLoadingEditProductId = false,
  }) {
    return AdminCatalogState(
      status: status ?? this.status,
      products: products ?? this.products,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      mutatingIds: mutatingIds ?? this.mutatingIds,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSavingNativeProduct:
          isSavingNativeProduct ?? this.isSavingNativeProduct,
      loadingEditProductId: clearLoadingEditProductId
          ? null
          : (loadingEditProductId ?? this.loadingEditProductId),
    );
  }
}
