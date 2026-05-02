/// Last-submitted checkout contact snapshot used to prefill the checkout
/// form on subsequent sessions.
///
/// Stored locally only. Promo code is intentionally excluded because codes
/// expire, can be revoked, and silently restoring them would mislead the
/// user into thinking a discount is applied.
class CheckoutDraftEntity {
  final String? name;
  final String? phone;
  final String? email;
  final String? loyaltyCard;
  final DateTime? updatedAt;

  const CheckoutDraftEntity({
    this.name,
    this.phone,
    this.email,
    this.loyaltyCard,
    this.updatedAt,
  });

  static const CheckoutDraftEntity empty = CheckoutDraftEntity();

  /// True when every contact field is null/blank. Used by the save pipeline
  /// to collapse a "cleared" draft into storage removal instead of an empty
  /// JSON payload.
  bool get isEmpty =>
      _blank(name) &&
      _blank(phone) &&
      _blank(email) &&
      _blank(loyaltyCard);

  /// Returns a copy with trimmed strings; empty/whitespace-only strings
  /// collapse to `null`. `updatedAt` is preserved.
  CheckoutDraftEntity normalized() {
    return CheckoutDraftEntity(
      name: _cleanup(name),
      phone: _cleanup(phone),
      email: _cleanup(email),
      loyaltyCard: _cleanup(loyaltyCard),
      updatedAt: updatedAt,
    );
  }

  CheckoutDraftEntity copyWith({
    String? name,
    String? phone,
    String? email,
    String? loyaltyCard,
    DateTime? updatedAt,
  }) {
    return CheckoutDraftEntity(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      loyaltyCard: loyaltyCard ?? this.loyaltyCard,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (loyaltyCard != null) 'loyalty_card': loyaltyCard,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  /// Tolerant parser: unknown keys ignored, missing keys treated as null,
  /// empty strings collapsed to null. Never throws on shape mismatch — the
  /// caller decides what to do with a resulting empty draft.
  static CheckoutDraftEntity fromJson(Map<String, dynamic> json) {
    return CheckoutDraftEntity(
      name: _cleanup(_asString(json['name'])),
      phone: _cleanup(_asString(json['phone'])),
      email: _cleanup(_asString(json['email'])),
      loyaltyCard: _cleanup(_asString(json['loyalty_card'])),
      updatedAt: _asDate(json['updated_at']),
    );
  }

  static String? _asString(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static DateTime? _asDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static String? _cleanup(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static bool _blank(String? value) {
    return value == null || value.trim().isEmpty;
  }
}
