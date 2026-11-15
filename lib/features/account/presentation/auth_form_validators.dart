final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateRegistrationEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Укажите email';
  if (!_emailPattern.hasMatch(email)) return 'Некорректный email';
  return null;
}

String? validateRegistrationPassword(String? value) {
  if (value == null || value.isEmpty) return 'Укажите пароль';
  if (value.length < 6) return 'Минимум 6 символов';
  return null;
}

String? validatePasswordConfirmation(String? value, String password) {
  if (value == null || value.isEmpty) return 'Подтвердите пароль';
  if (value != password) return 'Пароли не совпадают';
  return null;
}
