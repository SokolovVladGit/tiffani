const checkoutPhoneRequiredMessage = 'Укажите телефон';
const checkoutPhoneInvalidMessage = 'Некорректный номер телефона';

final _checkoutPhoneChars = RegExp(r'^[+\d ()-]+$');

/// Mandatory checkout phone. Counts digits, not the length of the typed text.
/// One leading + is optional. Spaces, parentheses and hyphens are display
/// separators. No country code is added.
String? validateCheckoutPhone(String? value) {
  if (value == null || value.trim().isEmpty) {
    return checkoutPhoneRequiredMessage;
  }
  final trimmed = value.trim();
  final plusCount = '+'.allMatches(trimmed).length;
  if (plusCount > 1 || (plusCount == 1 && !trimmed.startsWith('+'))) {
    return checkoutPhoneInvalidMessage;
  }
  if (!_checkoutPhoneChars.hasMatch(trimmed)) {
    return checkoutPhoneInvalidMessage;
  }
  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 8 || digits.length > 15) {
    return checkoutPhoneInvalidMessage;
  }
  return null;
}

/// Keeps a value the customer already typed. Fills only a blank field.
String fillCheckoutField(String current, String? incoming) {
  if (current.trim().isNotEmpty) return current;
  final value = incoming?.trim() ?? '';
  return value.isEmpty ? current : value;
}

/// Runs [persist] only after the order itself succeeded.
Future<void> persistPhoneAfterOrder({
  required bool orderSucceeded,
  required String phone,
  required Future<void> Function(String phone) persist,
}) async {
  if (!orderSucceeded) return;
  await persist(phone);
}

/// Profile sync and navigation are side effects. Either one failing must not
/// turn a committed order into a failed checkout.
Future<void> completeCheckoutSideEffects({
  required bool orderSucceeded,
  required Future<void> Function() persistPhone,
  required void Function() showSuccess,
}) async {
  if (!orderSucceeded) return;
  try {
    await persistPhone();
  } catch (_) {}
  showSuccess();
}
