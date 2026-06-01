import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/logger_service.dart';
import '../../domain/entities/admin_catalog_product.dart';
import '../../domain/entities/admin_native_product_form.dart';
import '../../domain/repositories/admin_catalog_repository.dart';
import '../dtos/admin_catalog_product_dto.dart';
import '../dtos/admin_native_product_detail_dto.dart';
import '../dtos/admin_native_product_payload_dto.dart';
import '../dtos/admin_native_product_upsert_result_dto.dart';

class AdminCatalogException implements Exception {
  AdminCatalogException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AdminCatalogRepositoryImpl implements AdminCatalogRepository {
  final SupabaseClient _client;
  final LoggerService _logger;

  static const _productsTable = 'products';
  static const _listLimit = 50;
  static const _selectColumns =
      'id, title, brand, category, mark, photo, is_active, app_is_visible, tilda_uid, created_at';

  const AdminCatalogRepositoryImpl(this._client, this._logger);

  @override
  Future<List<AdminCatalogProduct>> listProducts({String search = ''}) async {
    if (_client.auth.currentSession == null) {
      throw AdminCatalogException('Требуется вход в аккаунт администратора');
    }

    try {
      var query = _client.from(_productsTable).select(_selectColumns);

      final trimmed = search.trim();
      if (trimmed.isNotEmpty) {
        final pattern = '%${_escapeIlikePattern(trimmed)}%';
        query = query.or(
          'title.ilike.$pattern,'
          'brand.ilike.$pattern,'
          'category.ilike.$pattern,'
          'tilda_uid.ilike.$pattern',
        );
      }

      final rows = await query
          .order('created_at', ascending: false)
          .limit(_listLimit);

      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(AdminCatalogProductDto.fromMap)
          .map((dto) => dto.toEntity())
          .toList(growable: false);
    } on PostgrestException catch (e) {
      _logger.w('listProducts PostgrestException: ${e.message}');
      throw AdminCatalogException(_postgrestMessage(e));
    } catch (e, st) {
      _logger.e('listProducts failed: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<AdminCatalogVisibilityResult> setVisibility({
    required String productId,
    required bool visible,
  }) async {
    if (_client.auth.currentSession == null) {
      throw AdminCatalogException('Требуется вход в аккаунт администратора');
    }

    try {
      final raw = await _client.rpc(
        'admin_set_product_visibility',
        params: {
          'p_product_id': productId,
          'p_visible': visible,
        },
      );
      return visibilityResultFromRpc(raw);
    } on PostgrestException catch (e) {
      _logger.w('setVisibility PostgrestException: ${e.message}');
      throw AdminCatalogException(_postgrestMessage(e));
    } catch (e, st) {
      if (e is AdminCatalogException) rethrow;
      _logger.e('setVisibility failed: $e\n$st');
      rethrow;
    }
  }

  static String _escapeIlikePattern(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_')
        .replaceAll(',', '');
  }

  @override
  Future<AdminNativeProductForm> getNativeProductDetail(String productId) async {
    if (_client.auth.currentSession == null) {
      throw AdminCatalogException('Требуется вход в аккаунт администратора');
    }

    try {
      final productRow = await _client
          .from(_productsTable)
          .select(
            'id, title, brand, category, mark, description, text, photo, '
            'is_active, app_is_visible, tilda_uid',
          )
          .eq('id', productId)
          .maybeSingle();

      if (productRow == null) {
        throw AdminCatalogException('Товар не найден');
      }

      final productMap = Map<String, dynamic>.from(productRow);
      final tildaUid = productMap['tilda_uid'] as String?;
      if (tildaUid != null && tildaUid.trim().isNotEmpty) {
        throw AdminCatalogException(
          'Редактирование доступно только для товаров, созданных в приложении',
        );
      }

      final variantRows = await _client
          .from('product_variants')
          .select('variant_id, price, old_price, quantity, photo')
          .eq('product_id', productId);

      final variants = (variantRows as List).cast<Map<String, dynamic>>();
      if (variants.isEmpty) {
        throw AdminCatalogException('У товара нет вариантов');
      }
      if (variants.length > 1) {
        throw AdminCatalogException(
          'Редактирование товара с несколькими вариантами пока не поддерживается',
        );
      }

      final imageRows = await _client
          .from('product_images')
          .select('url, position')
          .eq('product_id', productId)
          .order('position', ascending: true);

      final images = (imageRows as List).cast<Map<String, dynamic>>();

      return AdminNativeProductDetailDto(
        product: productMap,
        variants: variants,
        images: images,
      ).toForm();
    } on AdminCatalogException {
      rethrow;
    } on FormatException catch (e) {
      throw AdminCatalogException(e.message);
    } on PostgrestException catch (e) {
      _logger.w('getNativeProductDetail PostgrestException: ${e.message}');
      throw AdminCatalogException(_postgrestMessage(e));
    } catch (e, st) {
      if (e is AdminCatalogException) rethrow;
      _logger.e('getNativeProductDetail failed: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<AdminNativeProductUpsertResult> upsertNativeProduct(
    AdminNativeProductForm form,
  ) async {
    if (_client.auth.currentSession == null) {
      throw AdminCatalogException('Требуется вход в аккаунт администратора');
    }

    try {
      final payload = AdminNativeProductPayloadDto(form).toJson();
      final raw = await _client.rpc(
        'admin_upsert_native_product',
        params: {'p_payload': payload},
      );
      return AdminNativeProductUpsertResultDto.parse(raw);
    } on PostgrestException catch (e) {
      _logger.w('upsertNativeProduct PostgrestException: ${e.message}');
      throw AdminCatalogException(_postgrestMessage(e));
    } catch (e, st) {
      if (e is AdminCatalogException) rethrow;
      _logger.e('upsertNativeProduct failed: $e\n$st');
      rethrow;
    }
  }

  static String _postgrestMessage(PostgrestException e) {
    final msg = e.message.trim();
    if (msg.isEmpty) return 'Ошибка сервера';
    final lower = msg.toLowerCase();
    if (lower.contains('admin access required')) {
      return 'Недостаточно прав администратора';
    }
    if (lower.contains('product not found')) {
      return 'Товар не найден';
    }
    if (lower.contains('tilda products cannot be edited')) {
      return 'Редактирование доступно только для товаров, созданных в приложении';
    }
    if (lower.contains('multi-variant native edit')) {
      return 'Редактирование товара с несколькими вариантами пока не поддерживается';
    }
    if (lower.contains('title is required')) {
      return 'Укажите название товара';
    }
    if (lower.contains('price is required')) {
      return 'Укажите цену';
    }
    if (lower.contains('row-level security') ||
        lower.contains('permission denied')) {
      return 'Недостаточно прав для этого действия';
    }
    return msg;
  }
}
