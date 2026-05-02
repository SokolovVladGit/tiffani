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
}
