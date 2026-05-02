import '../../domain/entities/order_quote_entity.dart';
import '../../domain/entities/order_result_entity.dart';

/// Tolerant parsers for `quote_order_v1` / `submit_order_v3` JSONB
/// responses. Never throws on malformed input — missing/garbage fields
/// degrade to safe defaults.
class OrderQuoteDto {
  OrderQuoteDto._();

  // ---------------------------------------------------------------------------
  // Quote parsing
  // ---------------------------------------------------------------------------

  /// Parses the response of `quote_order_v1`. Always returns a usable entity
  /// (with `ok=false` and a `quote_unavailable` synthetic error if [raw] is
  /// not even a Map).
  static OrderQuoteEntity parseQuote(Object? raw) {
    if (raw is! Map) {
      return const OrderQuoteEntity(
        ok: false,
        errors: [
          OrderQuoteErrorEntity(
            code: 'quote_unavailable',
            message: 'Не удалось получить расчёт заказа.',
          ),
        ],
      );
    }
    final m = raw.cast<String, dynamic>();

    final ok = _asBool(m['ok'], fallback: false);
    final pricingVersion = _asStringOrNull(m['pricing_version']);
    final errors = _parseErrors(m['errors']);

    if (!ok) {
      return OrderQuoteEntity(
        ok: false,
        pricingVersion: pricingVersion,
        errors: errors,
      );
    }

    final promo = _asMapOrNull(m['promo']);
    final promoStatus = promo == null ? null : _asStringOrNull(promo['status']);
    final promoMessage =
        promo == null ? null : _asStringOrNull(promo['message']);

    return OrderQuoteEntity(
      ok: true,
      pricingVersion: pricingVersion,
      subtotalAmount: _asDouble(m['subtotal_amount']),
      discountAmount: _asDouble(m['discount_amount']),
      fulfillmentFee: _asDouble(m['fulfillment_fee']),
      grandTotalAmount: _asDouble(m['grand_total_amount']),
      promoStatus: promoStatus,
      promoMessage: promoMessage,
      appliedDiscountLabels: _parseAppliedDiscountLabels(
        m['applied_discounts'],
      ),
      errors: errors,
    );
  }

  // ---------------------------------------------------------------------------
  // Submit-result parsing (v2 + v3, success path)
  //
  // v2 response shape: { order_id, total_items, total_quantity, total_price }
  // v3 response shape: v2 fields + Phase 1 snapshot fields + promo + applied_discounts
  // ---------------------------------------------------------------------------

  static OrderResultEntity parseOrderResult(Object? raw) {
    if (raw is! Map) {
      throw FormatException('Order result is not a map: $raw');
    }
    final m = raw.cast<String, dynamic>();

    final orderId = _asStringOrNull(m['order_id']);
    if (orderId == null || orderId.isEmpty) {
      throw const FormatException('Order result is missing order_id');
    }

    final promo = _asMapOrNull(m['promo']);

    return OrderResultEntity(
      orderId: orderId,
      totalItems: _asInt(m['total_items']),
      totalQuantity: _asInt(m['total_quantity']),
      totalPrice: _asDouble(m['total_price']),
      subtotalAmount: _asDoubleOrNull(m['subtotal_amount']),
      discountAmount: _asDoubleOrNull(m['discount_amount']),
      fulfillmentFee: _asDoubleOrNull(m['fulfillment_fee']),
      grandTotalAmount: _asDoubleOrNull(m['grand_total_amount']),
      pricingVersion: _asStringOrNull(m['pricing_version']),
      promoStatus: promo == null ? null : _asStringOrNull(promo['status']),
      promoMessage: promo == null ? null : _asStringOrNull(promo['message']),
    );
  }

  // ---------------------------------------------------------------------------
  // Error parsing (works for quote and submit error responses)
  // ---------------------------------------------------------------------------

  static List<OrderQuoteErrorEntity> parseErrors(Object? raw) {
    return _parseErrors(raw);
  }

  // ---------------------------------------------------------------------------
  // Russian localisation for known error codes (Phase 4 spec).
  //
  // Used by the cubit/repo when mapping an `ok=false` response to a UI
  // exception. Falls back to the backend-provided message if the code is
  // unknown.
  // ---------------------------------------------------------------------------

  static String localizeErrorCode(
    String code, {
    String? backendMessage,
  }) {
    switch (code) {
      // Customer/order validation (mirrors submit_order_v3)
      case 'missing_name':
        return 'Укажите имя';
      case 'missing_phone':
        return 'Укажите телефон';
      case 'missing_consent':
      case 'consent_required':
        return 'Необходимо согласие на обработку данных';
      case 'invalid_fulfillment_type':
        return 'Неверный тип получения заказа';
      case 'missing_pickup_store_id':
      case 'missing_pickup_store':
        return 'Выберите магазин для самовывоза';
      case 'invalid_pickup_zone':
      case 'invalid_pickup_address':
        return 'Зона/адрес доставки не задаются при самовывозе';
      case 'missing_delivery_zone':
      case 'delivery_zone_required':
        return 'Укажите зону доставки';
      case 'invalid_delivery_zone':
        return 'Неверная зона доставки';
      case 'missing_delivery_address':
      case 'delivery_address_required':
        return 'Укажите адрес доставки';
      case 'invalid_delivery_store':
        return 'Магазин самовывоза не задаётся при доставке';
      case 'invalid_fulfillment_method_code':
        return 'Неверный способ получения';
      case 'invalid_payment_method':
      case 'invalid_payment_method_code':
        return 'Неверный способ оплаты';
      case 'invalid_fulfillment_fee':
        return 'Стоимость доставки указана некорректно';

      // Cart/catalog
      case 'empty_items':
        return 'Корзина пуста';
      case 'unknown_variant':
        return 'Один из товаров недоступен. Удалите его из корзины.';
      case 'inactive_variant':
        return 'Один из товаров больше не доступен. Удалите его из корзины.';
      case 'no_price':
        return 'Для одного из товаров не задана цена. Удалите его из корзины.';

      // Promo (hard-fail gate from submit_order_v3)
      case 'promo_not_found':
        return 'Промокод не найден';
      case 'promo_inactive':
        return 'Промокод отключён';
      case 'promo_expired':
        return 'Срок действия промокода истёк';
      case 'promo_limit_reached':
        return 'Лимит использований промокода исчерпан';
      case 'promo_min_order_not_met':
        return 'Сумма заказа меньше минимальной для этого промокода';
      case 'promo_no_matching_items':
        return 'В корзине нет товаров, к которым применим этот промокод';

      // Concurrency
      case 'quote_changed_or_discount_unavailable':
        return 'Скидки изменились с момента расчёта. Пересчитайте заказ.';

      default:
        return backendMessage ?? 'Произошла ошибка. Попробуйте ещё раз.';
    }
  }

  /// Convenience: pre-formatted user-facing line for the quote's promo
  /// status field (used under the promo input).
  static String? humanizePromoStatus(
    String? status, {
    String? promoMessage,
  }) {
    if (status == null || status.isEmpty) return null;
    switch (status) {
      case 'applied':
        return 'Промокод применён';
      case 'not_best_discount':
        return 'Автоматическая скидка выгоднее — промокод не применён';
      case 'not_provided':
      case 'no_promo_input':
        return null;
      case 'not_found':
        return 'Промокод не найден';
      case 'inactive':
        return 'Промокод отключён';
      case 'expired':
        return 'Срок действия промокода истёк';
      case 'limit_reached':
        return 'Лимит использований промокода исчерпан';
      case 'min_order_not_met':
        return 'Сумма заказа меньше минимальной для этого промокода';
      case 'no_matching_items':
        return 'Промокод не применим к текущим товарам';
      default:
        return promoMessage ?? 'Промокод не применён';
    }
  }

  // ===========================================================================
  // Internal helpers — defensive type coercion.
  // ===========================================================================

  static List<OrderQuoteErrorEntity> _parseErrors(Object? raw) {
    if (raw is! List) return const [];
    final out = <OrderQuoteErrorEntity>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final em = e.cast<String, dynamic>();
      final code = _asStringOrNull(em['code']);
      if (code == null || code.isEmpty) continue;
      out.add(OrderQuoteErrorEntity(
        code: code,
        message: _asStringOrNull(em['message']) ?? code,
        variantId: _asStringOrNull(em['variant_id']),
      ));
    }
    return out;
  }

  static List<String> _parseAppliedDiscountLabels(Object? raw) {
    if (raw is! List) return const [];
    final out = <String>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final em = e.cast<String, dynamic>();
      final amount = _asDoubleOrNull(em['discount_amount']);
      if (amount != null && amount <= 0) continue;
      final kind = _asStringOrNull(em['kind']);
      final code = _asStringOrNull(em['code']);
      final name = _asStringOrNull(em['name']);
      final percent = _asDoubleOrNull(em['percent_off']);
      final percentText = percent == null ? '' : ' (-${_fmtPercent(percent)}%)';
      if (kind == 'promocode') {
        final visibleCode = code ?? name ?? '';
        out.add(visibleCode.isEmpty
            ? 'Промокод применён$percentText'
            : 'Промокод применён: $visibleCode$percentText');
      } else {
        final label = name ?? code ?? 'Скидка';
        out.add('Скидка: $label$percentText');
      }
    }
    return out;
  }

  static String _fmtPercent(double v) {
    if (v == v.truncateToDouble()) return v.toInt().toString();
    final s = v.toStringAsFixed(2);
    return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  static bool _asBool(Object? v, {bool fallback = false}) {
    if (v is bool) return v;
    if (v is String) {
      final t = v.toLowerCase().trim();
      if (t == 'true') return true;
      if (t == 'false') return false;
    }
    return fallback;
  }

  static int _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final n = num.tryParse(v.trim());
      if (n != null) return n.toInt();
    }
    return 0;
  }

  static double _asDouble(Object? v) => _asDoubleOrNull(v) ?? 0;

  static double? _asDoubleOrNull(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final n = num.tryParse(v.trim());
      return n?.toDouble();
    }
    return null;
  }

  static String? _asStringOrNull(Object? v) {
    if (v == null) return null;
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? null : t;
    }
    return v.toString();
  }

  static Map<String, dynamic>? _asMapOrNull(Object? v) {
    if (v is Map) return v.cast<String, dynamic>();
    return null;
  }
}
