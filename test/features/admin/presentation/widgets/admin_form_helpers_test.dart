import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tiffani/features/admin/presentation/widgets/admin_form_helpers.dart';

void main() {
  group('parseAdminDateInput', () {
    test('returns null for empty/whitespace input', () {
      expect(parseAdminDateInput(''), isNull);
      expect(parseAdminDateInput('   '), isNull);
    });

    test('parses YYYY-MM-DD HH:mm', () {
      final dt = parseAdminDateInput('2026-05-02 16:30');
      expect(dt, isNotNull);
      expect(dt!.year, 2026);
      expect(dt.month, 5);
      expect(dt.day, 2);
      expect(dt.hour, 16);
      expect(dt.minute, 30);
    });

    test('parses YYYY-MM-DDTHH:mm:ss as well', () {
      final dt = parseAdminDateInput('2026-05-02T16:30:45');
      expect(dt, isNotNull);
      expect(dt!.second, 45);
    });

    test('throws FormatException for malformed input', () {
      expect(
        () => parseAdminDateInput('05/02/2026'),
        throwsFormatException,
      );
      expect(
        () => parseAdminDateInput('2026-13-02 10:00'),
        throwsFormatException,
      );
      expect(
        () => parseAdminDateInput('2026-05-02 25:00'),
        throwsFormatException,
      );
    });
  });

  group('formatAdminDateInput', () {
    test('returns empty string for null', () {
      expect(formatAdminDateInput(null), '');
    });

    test('round-trips with parseAdminDateInput', () {
      final original = DateTime(2026, 5, 2, 16, 30);
      final formatted = formatAdminDateInput(original);
      expect(formatted, '2026-05-02 16:30');
      final parsed = parseAdminDateInput(formatted);
      expect(parsed, equals(original));
    });
  });

  group('startOfLocalDay', () {
    test('returns local midnight of the same day', () {
      final input = DateTime(2026, 5, 2, 16, 30, 45, 123);
      final result = startOfLocalDay(input);
      expect(result.year, 2026);
      expect(result.month, 5);
      expect(result.day, 2);
      expect(result.hour, 0);
      expect(result.minute, 0);
      expect(result.second, 0);
      expect(result.millisecond, 0);
    });
  });

  group('endOfLocalDay', () {
    test('returns 23:59:59.999 of the same local day', () {
      final input = DateTime(2026, 5, 2, 10, 15);
      final result = endOfLocalDay(input);
      expect(result.year, 2026);
      expect(result.month, 5);
      expect(result.day, 2);
      expect(result.hour, 23);
      expect(result.minute, 59);
      expect(result.second, 59);
      expect(result.millisecond, 999);
    });
  });

  group('formatValidityPeriodSummary', () {
    final now = DateTime(2026, 6, 15, 12);

    test('both null -> Без ограничения', () {
      expect(formatValidityPeriodSummary(null, null, now: now),
          'Без ограничения');
    });

    test('start only -> С <date>', () {
      final start = DateTime(2026, 5, 2);
      expect(
        formatValidityPeriodSummary(start, null, now: now),
        'С 2 мая',
      );
    });

    test('end only -> До <date>', () {
      final end = DateTime(2026, 5, 31, 23, 59, 59, 999);
      expect(
        formatValidityPeriodSummary(null, end, now: now),
        'До 31 мая',
      );
    });

    test('same local day -> single date', () {
      final start = DateTime(2026, 5, 2);
      final end = DateTime(2026, 5, 2, 23, 59, 59, 999);
      expect(
        formatValidityPeriodSummary(start, end, now: now),
        '2 мая',
      );
    });

    test('different days -> start — end', () {
      final start = DateTime(2026, 5, 2);
      final end = DateTime(2026, 5, 31, 23, 59, 59, 999);
      expect(
        formatValidityPeriodSummary(start, end, now: now),
        '2 мая — 31 мая',
      );
    });

    test('different years include year', () {
      final start = DateTime(2026, 12, 30);
      final end = DateTime(2027, 1, 5, 23, 59, 59, 999);
      expect(
        formatValidityPeriodSummary(start, end, now: now),
        '30 декабря — 5 января 2027',
      );
    });

    test('start year differs from current -> include year on start', () {
      final start = DateTime(2025, 11, 1);
      expect(
        formatValidityPeriodSummary(start, null, now: now),
        'С 1 ноября 2025',
      );
    });
  });

  group('generatePromocodeSuggestion', () {
    test('uses rounded percent hint as suffix when valid', () {
      final code = generatePromocodeSuggestion(
        percentHint: 15,
        random: Random(1),
      );
      expect(code.endsWith('15'), isTrue);
      expect(code, matches(r'^[A-Z]+15$'));
    });

    test('rounds fractional percent hint', () {
      final code = generatePromocodeSuggestion(
        percentHint: 14.6,
        random: Random(1),
      );
      expect(code.endsWith('15'), isTrue);
    });

    test('falls back when percent hint is null', () {
      final code = generatePromocodeSuggestion(random: Random(1));
      expect(code, matches(r'^[A-Z]+(10|15|20|25)$'));
    });

    test('falls back when percent hint is out of range', () {
      final codeZero =
          generatePromocodeSuggestion(percentHint: 0, random: Random(1));
      final codeOver =
          generatePromocodeSuggestion(percentHint: 150, random: Random(2));
      expect(codeZero, matches(r'^[A-Z]+(10|15|20|25)$'));
      expect(codeOver, matches(r'^[A-Z]+(10|15|20|25)$'));
    });

    test('result is uppercase ASCII with digit suffix', () {
      for (var i = 0; i < 20; i++) {
        final code = generatePromocodeSuggestion(random: Random(i));
        expect(code, matches(r'^[A-Z]+\d+$'));
      }
    });

    test('deterministic with identical seeds', () {
      final a = generatePromocodeSuggestion(
        percentHint: 20,
        random: Random(42),
      );
      final b = generatePromocodeSuggestion(
        percentHint: 20,
        random: Random(42),
      );
      expect(a, b);
    });
  });
}
