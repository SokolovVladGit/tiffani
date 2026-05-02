import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import 'admin_form_helpers.dart';

/// Immutable (start, end) pair emitted by [AdminValidityPeriodField].
@immutable
class AdminValidityPeriodValue {
  final DateTime? startsAt;
  final DateTime? endsAt;

  const AdminValidityPeriodValue({this.startsAt, this.endsAt});

  AdminValidityPeriodValue copyWith({
    DateTime? startsAt,
    DateTime? endsAt,
    bool clearStart = false,
    bool clearEnd = false,
  }) {
    return AdminValidityPeriodValue(
      startsAt: clearStart ? null : (startsAt ?? this.startsAt),
      endsAt: clearEnd ? null : (endsAt ?? this.endsAt),
    );
  }
}

/// Tappable readable summary of a discount campaign validity period.
///
/// Opens [_AdminValidityPeriodBottomSheet] on tap, which surfaces quick
/// presets (`Сегодня`, `7 дней`, `14 дней`, `30 дней`, `Этот месяц`,
/// `Без ограничения`) and calendar pickers for explicit start/end dates.
///
/// Emits normalized local-wall-clock values:
/// - `startsAt` is the local start of the day (00:00:00.000).
/// - `endsAt` is the local end of the day (23:59:59.999).
class AdminValidityPeriodField extends StatelessWidget {
  final DateTime? startsAt;
  final DateTime? endsAt;
  final ValueChanged<AdminValidityPeriodValue> onChanged;
  final String helperText;

  const AdminValidityPeriodField({
    super.key,
    required this.startsAt,
    required this.endsAt,
    required this.onChanged,
    this.helperText = 'Оставьте пустым, чтобы не ограничивать.',
  });

  Future<void> _open(BuildContext context) async {
    final result = await showModalBottomSheet<AdminValidityPeriodValue>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (_) => _AdminValidityPeriodBottomSheet(
        initial: AdminValidityPeriodValue(
          startsAt: startsAt,
          endsAt: endsAt,
        ),
      ),
    );
    if (result != null) {
      onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = formatValidityPeriodSummary(startsAt, endsAt);
    final isEmpty = startsAt == null && endsAt == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => _open(context),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.date_range_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    summary,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isEmpty ? FontWeight.w500 : FontWeight.w600,
                      color: isEmpty
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
        if (helperText.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            helperText,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}

class _AdminValidityPeriodBottomSheet extends StatefulWidget {
  final AdminValidityPeriodValue initial;

  const _AdminValidityPeriodBottomSheet({required this.initial});

  @override
  State<_AdminValidityPeriodBottomSheet> createState() =>
      _AdminValidityPeriodBottomSheetState();
}

class _AdminValidityPeriodBottomSheetState
    extends State<_AdminValidityPeriodBottomSheet> {
  late DateTime? _startsAt;
  late DateTime? _endsAt;

  @override
  void initState() {
    super.initState();
    _startsAt = widget.initial.startsAt;
    _endsAt = widget.initial.endsAt;
  }

  DateTime get _today => startOfLocalDay(DateTime.now());

  void _applyPreset(_PresetKind preset) {
    final today = _today;
    setState(() {
      switch (preset) {
        case _PresetKind.today:
          _startsAt = today;
          _endsAt = endOfLocalDay(today);
          break;
        case _PresetKind.days7:
          _startsAt = today;
          _endsAt = endOfLocalDay(today.add(const Duration(days: 6)));
          break;
        case _PresetKind.days14:
          _startsAt = today;
          _endsAt = endOfLocalDay(today.add(const Duration(days: 13)));
          break;
        case _PresetKind.days30:
          _startsAt = today;
          _endsAt = endOfLocalDay(today.add(const Duration(days: 29)));
          break;
        case _PresetKind.thisMonth:
          final firstDay = DateTime(today.year, today.month, 1);
          final lastDay = DateTime(today.year, today.month + 1, 0);
          _startsAt = firstDay;
          _endsAt = endOfLocalDay(lastDay);
          break;
        case _PresetKind.unlimited:
          _startsAt = null;
          _endsAt = null;
          break;
      }
    });
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final initial = (_startsAt ?? now).toLocal();
    final firstDate = DateTime(now.year - 5);
    final lastDate = DateTime(now.year + 10, 12, 31);
    final clampedInitial = _clamp(initial, firstDate, lastDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: clampedInitial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Дата начала',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );
    if (picked == null) return;
    final normalizedStart = startOfLocalDay(picked);
    setState(() {
      _startsAt = normalizedStart;
      // Keep end >= start: if end precedes the new start, snap end to the
      // same day's end-of-day.
      if (_endsAt != null && !_endsAt!.isAfter(normalizedStart)) {
        _endsAt = endOfLocalDay(picked);
      }
    });
  }

  Future<void> _pickEnd() async {
    final now = DateTime.now();
    final firstDate = _startsAt != null
        ? startOfLocalDay(_startsAt!)
        : DateTime(now.year - 5);
    final lastDate = DateTime(now.year + 10, 12, 31);
    final initial = (_endsAt ?? _startsAt ?? now).toLocal();
    final clampedInitial = _clamp(initial, firstDate, lastDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: clampedInitial,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Дата окончания',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );
    if (picked == null) return;
    setState(() {
      _endsAt = endOfLocalDay(picked);
    });
  }

  DateTime _clamp(DateTime value, DateTime min, DateTime max) {
    if (value.isBefore(min)) return min;
    if (value.isAfter(max)) return max;
    return value;
  }

  void _resetAll() {
    setState(() {
      _startsAt = null;
      _endsAt = null;
    });
  }

  void _submit() {
    Navigator.of(context).pop(
      AdminValidityPeriodValue(startsAt: _startsAt, endsAt: _endsAt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = formatValidityPeriodSummary(_startsAt, _endsAt);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Период действия',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  summary,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _PresetChip(
                      label: 'Сегодня',
                      onTap: () => _applyPreset(_PresetKind.today),
                    ),
                    _PresetChip(
                      label: '7 дней',
                      onTap: () => _applyPreset(_PresetKind.days7),
                    ),
                    _PresetChip(
                      label: '14 дней',
                      onTap: () => _applyPreset(_PresetKind.days14),
                    ),
                    _PresetChip(
                      label: '30 дней',
                      onTap: () => _applyPreset(_PresetKind.days30),
                    ),
                    _PresetChip(
                      label: 'Этот месяц',
                      onTap: () => _applyPreset(_PresetKind.thisMonth),
                    ),
                    _PresetChip(
                      label: 'Без ограничения',
                      onTap: () => _applyPreset(_PresetKind.unlimited),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _DateRow(
                  label: 'Начало',
                  value: _startsAt,
                  onTap: _pickStart,
                  onClear: _startsAt != null
                      ? () => setState(() => _startsAt = null)
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                _DateRow(
                  label: 'Окончание',
                  value: _endsAt,
                  onTap: _pickEnd,
                  onClear: _endsAt != null
                      ? () => setState(() => _endsAt = null)
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _resetAll,
                        child: const Text('Сбросить'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.textPrimary,
                          foregroundColor: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                        ),
                        child: const Text('Готово'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _PresetKind {
  today,
  days7,
  days14,
  days30,
  thisMonth,
  unlimited,
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceWarm,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateRow({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    final valueText = hasValue
        ? _formatDateOnly(value!.toLocal())
        : 'Не выбрано';

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                valueText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      hasValue ? FontWeight.w600 : FontWeight.w500,
                  color: hasValue
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
                ),
              ),
            ),
            if (onClear != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
                onPressed: onClear,
              ),
            const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDateOnly(DateTime local) {
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    return '$d.$m.${local.year}';
  }
}
