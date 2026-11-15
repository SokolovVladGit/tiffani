import 'entities/profile_entity.dart';

/// In-memory profile after a successful checkout.
///
/// Returns null when nothing should be written: blank phone, an unchanged
/// number, or a row that does not belong to the signed-in user. Name and
/// loyalty card stay on the entity so the account screen does not blank
/// them. They are not part of the database write.
ProfileEntity? profileAfterCheckoutPhone({
  required String userId,
  required ProfileEntity? existing,
  required String submittedPhone,
}) {
  final phone = submittedPhone.trim();
  if (phone.isEmpty) return null;
  if (existing != null && existing.id != userId) return null;

  final base = existing ?? ProfileEntity(id: userId);
  if (base.phone == phone) return null;

  return ProfileEntity(
    id: userId,
    name: base.name,
    phone: phone,
    loyaltyCard: base.loyaltyCard,
  );
}

/// Insert used only when the signed-in user has no profile row yet.
Map<String, dynamic> checkoutPhoneInsertPayload({
  required String userId,
  required String phone,
  required String updatedAt,
}) {
  return {'id': userId, 'phone': phone, 'updated_at': updatedAt};
}

/// Existing-row write. Name and loyalty_card are intentionally absent.
Map<String, dynamic> checkoutPhoneUpdatePayload({
  required String phone,
  required String updatedAt,
}) {
  return {'phone': phone, 'updated_at': updatedAt};
}
