import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Parses a `YYYY-MM-DD HH:mm` string into a UTC-aware DateTime stored
/// as the user's local wall-clock time. Returns `null` for empty input
/// and throws [FormatException] for malformed input.
DateTime? parseAdminDateInput(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final reg = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?$',
  );
  final m = reg.firstMatch(trimmed);
  if (m == null) {
    throw const FormatException(
      'Дата должна быть в формате ГГГГ-ММ-ДД ЧЧ:ММ',
    );
  }
  final year = int.parse(m.group(1)!);
  final month = int.parse(m.group(2)!);
  final day = int.parse(m.group(3)!);
  final hour = int.parse(m.group(4)!);
  final minute = int.parse(m.group(5)!);
  final second = int.tryParse(m.group(6) ?? '0') ?? 0;

  if (month < 1 || month > 12) {
    throw const FormatException('Неверный месяц');
  }
  if (day < 1 || day > 31) {
    throw const FormatException('Неверный день');
  }
  if (hour > 23 || minute > 59 || second > 59) {
    throw const FormatException('Неверное время');
  }

  return DateTime(year, month, day, hour, minute, second);
}

/// Formats a DateTime for the admin date text-field input.
/// Returns an empty string when [dt] is null.
String formatAdminDateInput(DateTime? dt) {
  if (dt == null) return '';
  final local = dt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final mo = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final h = local.hour.toString().padLeft(2, '0');
  final mi = local.minute.toString().padLeft(2, '0');
  return '$y-$mo-$d $h:$mi';
}

/// Pretty short date for cards (no seconds, dropped year for current year).
String formatAdminDateShort(DateTime? dt) {
  if (dt == null) return '—';
  final local = dt.toLocal();
  final d = local.day.toString().padLeft(2, '0');
  final mo = local.month.toString().padLeft(2, '0');
  final h = local.hour.toString().padLeft(2, '0');
  final mi = local.minute.toString().padLeft(2, '0');
  final yearPart =
      local.year == DateTime.now().year ? '' : '.${local.year}';
  return '$d.$mo$yearPart $h:$mi';
}

class AdminFieldLabel extends StatelessWidget {
  final String text;
  const AdminFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
