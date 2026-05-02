import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/tiffany_primary_button.dart';
import '../../domain/entities/discount_campaign_entity.dart';
import '../../domain/entities/discount_campaign_target_entity.dart';
import '../cubit/admin_discounts_cubit.dart';
import '../widgets/admin_form_helpers.dart';
import '../widgets/admin_target_editor.dart';
import '../widgets/admin_validity_period_field.dart';

/// Bottom-sheet form used to create or edit either a promocode or an
/// automatic discount. The same widget handles both `kind`s — the targets
/// editor is shown only for automatic discounts.
class AdminCampaignEditSheet extends StatefulWidget {
  final DiscountCampaignEntity initial;

  /// When true, editing the `kind`/`code` adapts UI; when false, the kind
  /// dropdown stays hidden (the kind is always derived from `initial`).
  const AdminCampaignEditSheet({super.key, required this.initial});

  static Future<DiscountCampaignEntity?> show(
    BuildContext context, {
    required AdminDiscountsCubit cubit,
    required DiscountCampaignEntity initial,
  }) {
    return showModalBottomSheet<DiscountCampaignEntity>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (sheetCtx) => BlocProvider.value(
        value: cubit,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: AdminCampaignEditSheet(initial: initial),
        ),
      ),
    );
  }

  @override
  State<AdminCampaignEditSheet> createState() => _AdminCampaignEditSheetState();
}

class _AdminCampaignEditSheetState extends State<AdminCampaignEditSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _codeCtrl;
  late TextEditingController _percentCtrl;
  late TextEditingController _minOrderCtrl;
  late TextEditingController _maxRedemptionsCtrl;
  late TextEditingController _descriptionCtrl;
  late bool _isActive;
  late List<DiscountCampaignTargetEntity> _targets;

  DateTime? _startsAt;
  DateTime? _endsAt;
  // Preserves legacy DateTime precision on unchanged edits: when the user
  // never opens the validity sheet, the original `starts_at`/`ends_at`
  // values are written back unchanged instead of being normalized to
  // start/end-of-day.
  bool _validityPeriodTouched = false;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _nameCtrl = TextEditingController(text: c.name);
    _codeCtrl = TextEditingController(text: c.code ?? '');
    _percentCtrl = TextEditingController(
      text: c.percentOff > 0 ? _trimNumeric(c.percentOff) : '',
    );
    _minOrderCtrl = TextEditingController(
      text: c.minOrderAmount > 0 ? _trimNumeric(c.minOrderAmount) : '',
    );
    _startsAt = c.startsAt;
    _endsAt = c.endsAt;
    _maxRedemptionsCtrl = TextEditingController(
      text: c.maxRedemptions?.toString() ?? '',
    );
    _descriptionCtrl = TextEditingController(text: c.description ?? '');
    _isActive = c.isActive;

    if (c.kind == DiscountCampaignKind.automatic) {
      _targets = c.targets.isEmpty
          ? const [
              DiscountCampaignTargetEntity(
                targetType: DiscountTargetType.all,
                matchMode: DiscountTargetMatchMode.exact,
              ),
            ]
          : List.of(c.targets);
    } else {
      _targets = const [];
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _percentCtrl.dispose();
    _minOrderCtrl.dispose();
    _maxRedemptionsCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    // Untouched edits must preserve the original persisted DateTime
    // precision (legacy campaigns may have non-midnight `starts_at` /
    // `ends_at` values). Only normalized values emitted by the validity
    // sheet replace them.
    final startsAt =
        _validityPeriodTouched ? _startsAt : widget.initial.startsAt;
    final endsAt =
        _validityPeriodTouched ? _endsAt : widget.initial.endsAt;

    if (startsAt != null && endsAt != null && !endsAt.isAfter(startsAt)) {
      _showError('Дата окончания должна быть позже даты начала');
      return;
    }

    final percent = double.tryParse(_percentCtrl.text.trim().replaceAll(',', '.'));
    if (percent == null || percent <= 0 || percent > 100) {
      _showError('Процент скидки должен быть числом от 0 до 100');
      return;
    }

    final minOrderText = _minOrderCtrl.text.trim().replaceAll(',', '.');
    double minOrder = 0;
    if (minOrderText.isNotEmpty) {
      final parsed = double.tryParse(minOrderText);
      if (parsed == null || parsed < 0) {
        _showError('Минимальная сумма заказа должна быть неотрицательной');
        return;
      }
      minOrder = parsed;
    }

    int? maxRedemptions;
    final maxRedText = _maxRedemptionsCtrl.text.trim();
    if (maxRedText.isNotEmpty) {
      final parsed = int.tryParse(maxRedText);
      if (parsed == null || parsed <= 0) {
        _showError('Лимит использований должен быть положительным целым числом');
        return;
      }
      maxRedemptions = parsed;
    }

    final isAutomatic = widget.initial.kind == DiscountCampaignKind.automatic;
    final isPromo = widget.initial.kind == DiscountCampaignKind.promocode;

    if (isPromo) {
      final code = _codeCtrl.text.trim();
      if (code.isEmpty) {
        _showError('Укажите код промокода');
        return;
      }
    }

    if (isAutomatic) {
      if (_targets.isEmpty) {
        _showError('Добавьте хотя бы одно условие');
        return;
      }
      for (final t in _targets) {
        if (!t.hasValidValue) {
          _showError(
            'Для условия «${t.targetType.russianLabel}» требуется значение',
          );
          return;
        }
      }
    }

    final updated = widget.initial.copyWith(
      name: _nameCtrl.text.trim(),
      code: isPromo ? _codeCtrl.text.trim().toUpperCase() : null,
      clearCode: !isPromo,
      description: _descriptionCtrl.text.trim().isEmpty
          ? null
          : _descriptionCtrl.text.trim(),
      clearDescription: _descriptionCtrl.text.trim().isEmpty,
      percentOff: percent,
      minOrderAmount: minOrder,
      startsAt: startsAt,
      clearStartsAt: startsAt == null,
      endsAt: endsAt,
      clearEndsAt: endsAt == null,
      maxRedemptions: maxRedemptions,
      clearMaxRedemptions: maxRedemptions == null,
      isActive: _isActive,
      targets: isAutomatic ? List.unmodifiable(_targets) : const [],
    );

    setState(() => _saving = true);
    final saved = await context.read<AdminDiscountsCubit>().saveCampaign(
      updated,
      onError: _showError,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved != null) {
      Navigator.of(context).pop(saved);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _trimNumeric(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  void _onGenerateCode() {
    final hint = double.tryParse(
      _percentCtrl.text.trim().replaceAll(',', '.'),
    );
    final suggestion = generatePromocodeSuggestion(percentHint: hint);
    _codeCtrl.value = TextEditingValue(
      text: suggestion,
      selection: TextSelection.collapsed(offset: suggestion.length),
    );
  }

  void _applyPercentPreset(int percent) {
    final text = percent.toString();
    _percentCtrl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPromo = widget.initial.kind == DiscountCampaignKind.promocode;
    final isAutomatic = !isPromo;
    final isPersisted = widget.initial.isPersisted;
    final title = isPromo
        ? (isPersisted ? 'Редактирование промокода' : 'Новый промокод')
        : (isPersisted
            ? 'Редактирование скидки'
            : 'Новая автоматическая скидка');
    final submitLabel = _submitLabel(isPromo: isPromo, isPersisted: isPersisted);

    // Local input theme override: softer focused border (dark-gray action
    // tone) instead of the global pure-black focused border, scoped to
    // this admin form only.
    final baseTheme = Theme.of(context);
    final baseInputTheme = baseTheme.inputDecorationTheme;
    final adminInputTheme = baseInputTheme.copyWith(
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(
          color: AppColors.action,
          width: 1.2,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(
          color: AppColors.border.withValues(alpha: 0.8),
        ),
      ),
    );

    return Theme(
      data: baseTheme.copyWith(inputDecorationTheme: adminInputTheme),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.92,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SheetHeader(title: title),
                Flexible(
                  child: ListView(
                    controller: ScrollController(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.xxxl,
                    ),
                  children: [
                    _AdminFormSection(
                      title: 'Основное',
                      children: [
                        const AdminFieldLabel('Название'),
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Например: Весна-25',
                          ),
                          validator: (v) {
                            if ((v ?? '').trim().isEmpty) {
                              return 'Укажите название';
                            }
                            return null;
                          },
                        ),
                        if (isPromo) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            children: [
                              const Expanded(child: AdminFieldLabel('Код')),
                              _InlineAction(
                                icon: Icons.auto_awesome_outlined,
                                label: 'Сгенерировать',
                                onTap: _onGenerateCode,
                              ),
                            ],
                          ),
                          TextFormField(
                            controller: _codeCtrl,
                            textCapitalization:
                                TextCapitalization.characters,
                            style: const TextStyle(
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'NEWYEAR15',
                            ),
                            onChanged: (v) {
                              final upper = v.toUpperCase();
                              if (upper != v) {
                                _codeCtrl.value = TextEditingValue(
                                  text: upper,
                                  selection: TextSelection.collapsed(
                                    offset: upper.length,
                                  ),
                                );
                              }
                            },
                            validator: (v) {
                              if ((v ?? '').trim().isEmpty) {
                                return 'Укажите код';
                              }
                              return null;
                            },
                          ),
                          const _FieldHint(
                            text:
                                'Покупатель вводит этот код при оформлении заказа.',
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        const AdminFieldLabel('Процент скидки'),
                        TextFormField(
                          controller: _percentCtrl,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'от 0 до 100',
                            suffixText: '%',
                          ),
                          validator: (v) {
                            final s =
                                (v ?? '').trim().replaceAll(',', '.');
                            if (s.isEmpty) return 'Укажите процент скидки';
                            final p = double.tryParse(s);
                            if (p == null || p <= 0 || p > 100) {
                              return 'Введите число от 0 до 100';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _percentCtrl,
                          builder: (_, value, _) {
                            final current = double.tryParse(
                              value.text.trim().replaceAll(',', '.'),
                            );
                            return _PercentPresetRow(
                              selectedPercent: current,
                              onTap: _applyPercentPreset,
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _AdminFormSection(
                      title: 'Ограничения',
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const AdminFieldLabel('Мин. сумма'),
                                  TextFormField(
                                    controller: _minOrderCtrl,
                                    keyboardType: const TextInputType
                                        .numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(
                                      hintText: '0',
                                      suffixText: '₽',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const AdminFieldLabel(
                                      'Лимит использований'),
                                  TextFormField(
                                    controller: _maxRedemptionsCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      hintText: 'без лимита',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const _FieldHint(
                          text:
                              '0 — без минимальной суммы. Лимит можно оставить пустым.',
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const AdminFieldLabel('Период действия'),
                        AdminValidityPeriodField(
                          startsAt: _startsAt,
                          endsAt: _endsAt,
                          helperText:
                              'Если период не выбран, скидка действует без ограничения.',
                          onChanged: (value) {
                            setState(() {
                              _startsAt = value.startsAt;
                              _endsAt = value.endsAt;
                              _validityPeriodTouched = true;
                            });
                          },
                        ),
                        if (isAutomatic) ...[
                          const SizedBox(height: AppSpacing.lg),
                          const AdminFieldLabel('Условия'),
                          const SizedBox(height: AppSpacing.xs),
                          AdminTargetEditor(
                            targets: _targets,
                            onChanged: (next) => setState(() {
                              _targets = List.of(next);
                            }),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _AdminFormSection(
                      title: 'Дополнительно',
                      children: [
                        const AdminFieldLabel('Описание'),
                        TextFormField(
                          controller: _descriptionCtrl,
                          maxLines: 3,
                          minLines: 2,
                          decoration: const InputDecoration(
                            hintText: 'Короткое описание для администратора',
                          ),
                        ),
                        const _FieldHint(
                          text: 'Необязательное поле.',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceWarm,
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: AppColors.border),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 2,
                          ),
                          child: SwitchListTile.adaptive(
                            title: const Text(
                              'Активна',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              _isActive
                                  ? 'Применяется к заказам'
                                  : 'Не применяется к заказам',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                            contentPadding: EdgeInsets.zero,
                            value: _isActive,
                            onChanged: (v) =>
                                setState(() => _isActive = v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(color: AppColors.divider),
                  ),
                ),
                child: TiffanyPrimaryButton(
                  label: submitLabel,
                  onPressed: _saving ? null : _onSave,
                  isLoading: _saving,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  String _submitLabel({required bool isPromo, required bool isPersisted}) {
    if (isPersisted) {
      return isPromo ? 'Сохранить промокод' : 'Сохранить скидку';
    }
    return isPromo ? 'Создать промокод' : 'Создать скидку';
  }

}

class _AdminFormSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _AdminFormSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _FieldHint extends StatelessWidget {
  final String text;
  const _FieldHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textTertiary,
          height: 1.35,
        ),
      ),
    );
  }
}

class _InlineAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _InlineAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.textPrimary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PercentPresetRow extends StatelessWidget {
  static const List<int> presets = [5, 10, 15, 20, 25];

  final double? selectedPercent;
  final ValueChanged<int> onTap;

  const _PercentPresetRow({
    required this.selectedPercent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: presets.map((value) {
        final isSelected =
            selectedPercent != null && selectedPercent == value.toDouble();
        return _PercentChip(
          label: '$value%',
          selected: isSelected,
          onTap: () => onTap(value),
        );
      }).toList(),
    );
  }
}

class _PercentChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PercentChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.textPrimary : AppColors.surfaceWarm,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: selected ? AppColors.textPrimary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.surface : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;
  const _SheetHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
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
    );
  }
}

