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
  late TextEditingController _startsCtrl;
  late TextEditingController _endsCtrl;
  late TextEditingController _maxRedemptionsCtrl;
  late TextEditingController _descriptionCtrl;
  late bool _isActive;
  late List<DiscountCampaignTargetEntity> _targets;

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
    _startsCtrl = TextEditingController(text: formatAdminDateInput(c.startsAt));
    _endsCtrl = TextEditingController(text: formatAdminDateInput(c.endsAt));
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
    _startsCtrl.dispose();
    _endsCtrl.dispose();
    _maxRedemptionsCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    DateTime? startsAt;
    DateTime? endsAt;
    try {
      startsAt = parseAdminDateInput(_startsCtrl.text);
    } on FormatException catch (e) {
      _showError('Неверная дата начала: ${e.message}');
      return;
    }
    try {
      endsAt = parseAdminDateInput(_endsCtrl.text);
    } on FormatException catch (e) {
      _showError('Неверная дата окончания: ${e.message}');
      return;
    }

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

  @override
  Widget build(BuildContext context) {
    final isPromo = widget.initial.kind == DiscountCampaignKind.promocode;
    final isAutomatic = !isPromo;
    final title = isPromo
        ? (widget.initial.isPersisted
            ? 'Редактирование промокода'
            : 'Новый промокод')
        : (widget.initial.isPersisted
            ? 'Редактирование скидки'
            : 'Новая автоматическая скидка');

    return SafeArea(
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
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
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
                      const AdminFieldLabel('Код'),
                      TextFormField(
                        controller: _codeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          hintText: 'NEWYEAR15',
                        ),
                        onChanged: (v) {
                          final upper = v.toUpperCase();
                          if (upper != v) {
                            _codeCtrl.value = TextEditingValue(
                              text: upper,
                              selection:
                                  TextSelection.collapsed(offset: upper.length),
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
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    const AdminFieldLabel('Процент скидки'),
                    TextFormField(
                      controller: _percentCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'от 0 до 100',
                        suffixText: '%',
                      ),
                      validator: (v) {
                        final s = (v ?? '').trim().replaceAll(',', '.');
                        if (s.isEmpty) return 'Укажите процент скидки';
                        final p = double.tryParse(s);
                        if (p == null || p <= 0 || p > 100) {
                          return 'Введите число от 0 до 100';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AdminFieldLabel('Мин. сумма'),
                              TextFormField(
                                controller: _minOrderCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AdminFieldLabel('Лимит использований'),
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
                    const SizedBox(height: AppSpacing.lg),
                    const AdminFieldLabel('Период действия'),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _startsCtrl,
                            decoration: const InputDecoration(
                              hintText: 'ГГГГ-ММ-ДД ЧЧ:ММ',
                              labelText: 'Начало',
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextFormField(
                            controller: _endsCtrl,
                            decoration: const InputDecoration(
                              hintText: 'ГГГГ-ММ-ДД ЧЧ:ММ',
                              labelText: 'Окончание',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Оставьте поле пустым, чтобы не ограничивать.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const AdminFieldLabel('Описание'),
                    TextFormField(
                      controller: _descriptionCtrl,
                      maxLines: 3,
                      minLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Не обязательно',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SwitchListTile.adaptive(
                      title: const Text(
                        'Активна',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
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
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                    if (isAutomatic) ...[
                      const SizedBox(height: AppSpacing.lg),
                      const Divider(height: 1),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Условия',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addTarget,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Добавить'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Хотя бы одно условие. Используйте «Все товары» для скидки без ограничений.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ..._targets.asMap().entries.map((entry) {
                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _TargetRow(
                            target: entry.value,
                            onChanged: (next) => setState(() {
                              _targets[entry.key] = next;
                            }),
                            onRemove: _targets.length > 1
                                ? () => setState(() {
                                      _targets.removeAt(entry.key);
                                    })
                                : null,
                          ),
                        );
                      }),
                    ],
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
                  label: 'Сохранить',
                  onPressed: _saving ? null : _onSave,
                  isLoading: _saving,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addTarget() {
    setState(() {
      _targets.add(const DiscountCampaignTargetEntity(
        targetType: DiscountTargetType.brand,
        matchMode: DiscountTargetMatchMode.exact,
      ));
    });
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

class _TargetRow extends StatelessWidget {
  final DiscountCampaignTargetEntity target;
  final ValueChanged<DiscountCampaignTargetEntity> onChanged;
  final VoidCallback? onRemove;

  const _TargetRow({
    required this.target,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final showValue = target.targetType.requiresValue;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<DiscountTargetType>(
                  initialValue: target.targetType,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Тип',
                    isDense: true,
                  ),
                  items: DiscountTargetType.values
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t.russianLabel),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    onChanged(target.copyWith(
                      targetType: v,
                      clearTargetValue: v == DiscountTargetType.all,
                    ));
                  },
                ),
              ),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: AppColors.textTertiary,
                  ),
                ),
            ],
          ),
          if (showValue) ...[
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              initialValue: target.targetValue,
              decoration: const InputDecoration(
                labelText: 'Значение',
                isDense: true,
                hintText: 'например: Hermes / Парфюмерия / UID',
              ),
              onChanged: (v) =>
                  onChanged(target.copyWith(targetValue: v.trim())),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<DiscountTargetMatchMode>(
              initialValue: target.matchMode,
              isDense: true,
              decoration: const InputDecoration(
                labelText: 'Совпадение',
                isDense: true,
              ),
              items: DiscountTargetMatchMode.values
                  .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(m.russianLabel),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                onChanged(target.copyWith(matchMode: v));
              },
            ),
          ],
        ],
      ),
    );
  }
}
