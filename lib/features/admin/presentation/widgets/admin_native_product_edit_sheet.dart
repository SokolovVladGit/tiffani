import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/tiffany_primary_button.dart';
import '../../domain/entities/admin_native_product_form.dart';
import '../cubit/admin_catalog_cubit.dart';
import '../cubit/admin_catalog_state.dart';

class AdminNativeProductEditSheet extends StatefulWidget {
  final AdminNativeProductForm initial;

  const AdminNativeProductEditSheet({super.key, required this.initial});

  static Future<bool?> showCreate(
    BuildContext context, {
    required AdminCatalogCubit cubit,
  }) {
    return showModalBottomSheet<bool>(
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
          child: AdminNativeProductEditSheet(
            initial: AdminNativeProductForm.empty(),
          ),
        ),
      ),
    );
  }

  static Future<bool?> showEdit(
    BuildContext context, {
    required AdminCatalogCubit cubit,
    required AdminNativeProductForm initial,
  }) {
    return showModalBottomSheet<bool>(
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
          child: AdminNativeProductEditSheet(initial: initial),
        ),
      ),
    );
  }

  @override
  State<AdminNativeProductEditSheet> createState() =>
      _AdminNativeProductEditSheetState();
}

class _AdminNativeProductEditSheetState extends State<AdminNativeProductEditSheet> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _markCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _textCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _oldPriceCtrl;
  late final TextEditingController _quantityCtrl;

  late bool _appIsVisible;
  final List<TextEditingController> _imageUrlCtrls = [];

  String? _formError;
  bool _saving = false;

  bool get _isEdit => widget.initial.isEdit;

  @override
  void initState() {
    super.initState();
    final f = widget.initial;
    _titleCtrl = TextEditingController(text: f.title);
    _brandCtrl = TextEditingController(text: f.brand ?? '');
    _categoryCtrl = TextEditingController(text: f.category ?? '');
    _markCtrl = TextEditingController(text: f.mark ?? '');
    _descriptionCtrl = TextEditingController(text: f.description ?? '');
    _textCtrl = TextEditingController(text: f.text ?? '');
    _priceCtrl = TextEditingController(
      text: f.price != null ? _formatNum(f.price!) : '',
    );
    _oldPriceCtrl = TextEditingController(
      text: f.oldPrice != null ? _formatNum(f.oldPrice!) : '',
    );
    _quantityCtrl = TextEditingController(text: f.quantity.toString());
    _appIsVisible = f.appIsVisible;

    if (f.imageUrls.isEmpty) {
      _addImageRow('');
    } else {
      for (final url in f.imageUrls) {
        _addImageRow(url);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _titleCtrl.dispose();
    _brandCtrl.dispose();
    _categoryCtrl.dispose();
    _markCtrl.dispose();
    _descriptionCtrl.dispose();
    _textCtrl.dispose();
    _priceCtrl.dispose();
    _oldPriceCtrl.dispose();
    _quantityCtrl.dispose();
    for (final c in _imageUrlCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addImageRow([String value = '']) {
    if (_imageUrlCtrls.length >= 30) return;
    setState(() {
      _imageUrlCtrls.add(TextEditingController(text: value));
    });
  }

  void _removeImageRow(int index) {
    if (index < 0 || index >= _imageUrlCtrls.length) return;
    setState(() {
      _imageUrlCtrls[index].dispose();
      _imageUrlCtrls.removeAt(index);
      if (_imageUrlCtrls.isEmpty) {
        _imageUrlCtrls.add(TextEditingController());
      }
    });
  }

  String _formatNum(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toString();
  }

  List<String> _imageUrlInputs() =>
      _imageUrlCtrls.map((c) => c.text).toList(growable: false);

  Future<void> _onSave() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _formError = null);

    if (!_formKey.currentState!.validate()) return;

    final validationError = AdminNativeProductForm.empty().validateForSave(
      titleInput: _titleCtrl.text,
      priceInput: _priceCtrl.text,
      oldPriceInput: _oldPriceCtrl.text,
      quantityInput: _quantityCtrl.text,
      imageUrlInputs: _imageUrlInputs(),
    );
    if (validationError != null) {
      setState(() => _formError = validationError);
      return;
    }

    final form = widget.initial.toValidated(
      titleInput: _titleCtrl.text,
      priceInput: _priceCtrl.text,
      oldPriceInput: _oldPriceCtrl.text,
      quantityInput: _quantityCtrl.text,
      imageUrlInputs: _imageUrlInputs(),
      appIsVisible: _appIsVisible,
    ).copyWith(
      brand: AdminNativeProductForm.normalizeOptional(_brandCtrl.text),
      category: AdminNativeProductForm.normalizeOptional(_categoryCtrl.text),
      mark: AdminNativeProductForm.normalizeOptional(_markCtrl.text),
      description:
          AdminNativeProductForm.normalizeOptional(_descriptionCtrl.text),
      text: AdminNativeProductForm.normalizeOptional(_textCtrl.text),
    );

    setState(() => _saving = true);
    final cubit = context.read<AdminCatalogCubit>();
    final ok = await cubit.saveNativeProduct(form);
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      final msg = cubit.state.errorMessage;
      setState(() => _formError = msg ?? 'Не удалось сохранить товар');
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final adminInputTheme = baseTheme.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: AppColors.surfaceDim,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 14,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.action, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(
          color: AppColors.border.withValues(alpha: 0.8),
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.textSecondary),
      ),
      labelStyle: const TextStyle(
        fontSize: 14,
        color: AppColors.textSecondary,
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );

    return BlocBuilder<AdminCatalogCubit, AdminCatalogState>(
      buildWhen: (prev, curr) =>
          prev.isSavingNativeProduct != curr.isSavingNativeProduct,
      builder: (context, state) {
        final saving = _saving || state.isSavingNativeProduct;
        final title = _isEdit ? 'Редактировать товар' : 'Добавить товар';
        final submitLabel = _isEdit ? 'Сохранить' : 'Создать';

        return Theme(
          data: baseTheme.copyWith(inputDecorationTheme: adminInputTheme),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.92,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SheetHeader(
                      title: title,
                      onClose: saving ? null : () => Navigator.pop(context),
                    ),
                    Flexible(
                      child: ListView(
                        controller: _scrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.lg,
                        ),
                        children: [
                          if (_formError != null) ...[
                            _ErrorBanner(message: _formError!),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          _FormSection(
                            title: 'Основное',
                            children: [
                              _field(
                                controller: _titleCtrl,
                                label: 'Название',
                                isRequired: true,
                                maxLength: 500,
                                textInputAction: TextInputAction.next,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Укажите название';
                                  }
                                  if (v.trim().length > 500) {
                                    return 'Максимум 500 символов';
                                  }
                                  return null;
                                },
                              ),
                              _field(
                                controller: _brandCtrl,
                                label: 'Бренд',
                                textInputAction: TextInputAction.next,
                              ),
                              _field(
                                controller: _categoryCtrl,
                                label: 'Категория',
                                textInputAction: TextInputAction.next,
                              ),
                              _field(
                                controller: _markCtrl,
                                label: 'Метка',
                                textInputAction: TextInputAction.next,
                              ),
                              _field(
                                controller: _descriptionCtrl,
                                label: 'Краткое описание',
                                maxLines: 2,
                              ),
                              _field(
                                controller: _textCtrl,
                                label: 'Полное описание',
                                maxLines: 4,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _FormSection(
                            title: 'Цена и наличие',
                            children: [
                              _field(
                                controller: _priceCtrl,
                                label: 'Цена',
                                isRequired: true,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.,]'),
                                  ),
                                ],
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Укажите цену';
                                  }
                                  final p =
                                      AdminNativeProductForm.parseDecimal(v);
                                  if (p == null || p < 0) {
                                    return 'Некорректная цена';
                                  }
                                  return null;
                                },
                              ),
                              _field(
                                controller: _oldPriceCtrl,
                                label: 'Старая цена',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.,]'),
                                  ),
                                ],
                              ),
                              _field(
                                controller: _quantityCtrl,
                                label: 'Количество',
                                isRequired: true,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Укажите количество';
                                  }
                                  final q = AdminNativeProductForm.parseInt(v);
                                  if (q == null || q < 0) {
                                    return 'Некорректное количество';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _FormSection(
                            title: 'Изображения',
                            children: [
                              const Text(
                                'Ссылки http/https, до 30. Первый — главное фото.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              for (var i = 0; i < _imageUrlCtrls.length; i++)
                                _ImageUrlRow(
                                  index: i,
                                  controller: _imageUrlCtrls[i],
                                  enabled: !saving,
                                  onRemove: () => _removeImageRow(i),
                                ),
                              const SizedBox(height: AppSpacing.xs),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: saving || _imageUrlCtrls.length >= 30
                                      ? null
                                      : _addImageRow,
                                  icon: const Icon(Icons.add_link, size: 18),
                                  label: Text(
                                    _imageUrlCtrls.length >= 30
                                        ? 'Лимит 30 URL'
                                        : 'Добавить ссылку',
                                  ),
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(0, 44),
                                    foregroundColor: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _FormSection(
                            title: 'Видимость',
                            children: [
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Показывать в каталоге',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  _appIsVisible
                                      ? 'Товар виден в приложении'
                                      : 'Товар скрыт, но остаётся в списке',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.35,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                                value: _appIsVisible,
                                onChanged: saving
                                    ? null
                                    : (v) => setState(() => _appIsVisible = v),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.lg +
                            MediaQuery.paddingOf(context).bottom,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        border: Border(top: BorderSide(color: AppColors.divider)),
                      ),
                      child: TiffanyPrimaryButton(
                        onPressed: saving ? null : _onSave,
                        label: submitLabel,
                        isLoading: saving,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    bool isRequired = false,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    final displayLabel = isRequired ? '$label *' : label;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        inputFormatters: inputFormatters,
        validator: validator,
        decoration: InputDecoration(
          labelText: displayLabel,
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onClose;

  const _SheetHeader({required this.title, this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
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
              Semantics(
                button: true,
                label: 'Закрыть',
                child: IconButton(
                  onPressed: onClose,
                  tooltip: 'Закрыть',
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _FormSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _ImageUrlRow extends StatelessWidget {
  final int index;
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onRemove;

  const _ImageUrlRow({
    required this.index,
    required this.controller,
    required this.enabled,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: SizedBox(
              width: 22,
              child: Text(
                '${index + 1}.',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              enabled: enabled,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'URL изображения',
                hintText: 'https://…',
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Удалить ссылку ${index + 1}',
            child: IconButton(
              onPressed: enabled ? onRemove : null,
              tooltip: 'Удалить',
              icon: const Icon(Icons.remove_circle_outline, size: 22),
              style: IconButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                minimumSize: const Size(44, 44),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceDim,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            size: 20,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
