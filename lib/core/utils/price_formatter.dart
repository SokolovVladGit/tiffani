class PriceFormatter {
  PriceFormatter._();

  static String formatRub(double? value) {
    if (value == null) return '';
    if (value == value.truncateToDouble()) {
      return '${value.toInt()} ₽';
    }
    final formatted = value.toStringAsFixed(2);
    final trimmed = formatted.replaceAll(RegExp(r'0+$'), '');
    return '$trimmed ₽';
  }
}
