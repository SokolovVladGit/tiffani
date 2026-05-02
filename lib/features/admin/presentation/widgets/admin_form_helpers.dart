import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

const List<String> _promocodePrefixes = [
  'TIFFANI',
  'BEAUTY',
  'GLOW',
  'SPRING',
  'VIP',
  'SHINE',
  'LUXE',
];

const List<int> _promocodeFallbackSuffixes = [10, 15, 20, 25];

/// Generates a friendly uppercase promocode suggestion.
///
/// - [percentHint] — when in the inclusive (0, 100] range, its rounded
///   integer is appended as the numeric suffix (`15` → `BEAUTY15`).
/// - Otherwise a fallback suffix from 10/15/20/25 is used.
/// - [random] — optional injection point for deterministic tests.
///
/// No backend uniqueness check is performed; Supabase retains the unique
/// constraint on `discount_campaigns.code`.
String generatePromocodeSuggestion({
  double? percentHint,
  Random? random,
}) {
  final rng = random ?? Random();
  final prefix = _promocodePrefixes[rng.nextInt(_promocodePrefixes.length)];
  final int suffix;
  if (percentHint != null &&
      percentHint > 0 &&
      percentHint <= 100 &&
      percentHint.isFinite) {
    suffix = percentHint.round();
  } else {
    suffix = _promocodeFallbackSuffixes[
        rng.nextInt(_promocodeFallbackSuffixes.length)];
  }
  return '$prefix$suffix';
}

const List<String> _russianMonthsGenitive = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

/// Returns the local-wall-clock start of the day (00:00:00.000) for [value].
DateTime startOfLocalDay(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Returns the local-wall-clock end of the day (23:59:59.999) for [value].
///
/// Used for `ends_at` snapshots so that "до 31 мая" remains valid
/// through the entire local day when converted to UTC ISO for Supabase.
DateTime endOfLocalDay(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day, 23, 59, 59, 999);
}

/// Human-readable Russian summary of a validity period for
/// `discount_campaigns.starts_at` / `ends_at`.
///
/// Formatting rules:
/// - Both null: `Без ограничения`.
/// - Start only: `С 2 мая`.
/// - End only: `До 31 мая`.
/// - Same local day: `2 мая`.
/// - Different days: `2 мая — 31 мая`.
/// - Year is omitted when equal to the current local year, included otherwise.
///
/// [now] is an optional injection point for testing the "current year" rule;
/// defaults to `DateTime.now()`.
String formatValidityPeriodSummary(
  DateTime? start,
  DateTime? end, {
  DateTime? now,
}) {
  if (start == null && end == null) return 'Без ограничения';
  final reference = (now ?? DateTime.now()).toLocal();
  final refYear = reference.year;

  if (start != null && end != null) {
    final s = start.toLocal();
    final e = end.toLocal();
    final sameDay = s.year == e.year && s.month == e.month && s.day == e.day;
    if (sameDay) {
      return _formatRussianDate(s, refYear);
    }
    return '${_formatRussianDate(s, refYear)} — ${_formatRussianDate(e, refYear)}';
  }

  if (start != null) {
    return 'С ${_formatRussianDate(start.toLocal(), refYear)}';
  }
  return 'До ${_formatRussianDate(end!.toLocal(), refYear)}';
}

String _formatRussianDate(DateTime localValue, int referenceYear) {
  final day = localValue.day;
  final month = _russianMonthsGenitive[localValue.month - 1];
  if (localValue.year == referenceYear) {
    return '$day $month';
  }
  return '$day $month ${localValue.year}';
}

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
