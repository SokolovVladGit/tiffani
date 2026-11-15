/// Same short reference the Telegram worker prints: the first eight
/// characters of the order UUID, uppercased.
String shortOrderReference(String orderId) {
  final trimmed = orderId.trim();
  if (trimmed.length < 8) return trimmed.toUpperCase();
  return trimmed.substring(0, 8).toUpperCase();
}
