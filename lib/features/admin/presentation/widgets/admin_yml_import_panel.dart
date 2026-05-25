import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/constants/admin_yml_import_limits.dart';
import '../../domain/entities/admin_yml_import_result_entity.dart';
import '../cubit/admin_yml_import_cubit.dart';
import '../cubit/admin_yml_import_state.dart';

/// Admin manual Tilda YML import (fallback when public feed URL is down).
class AdminYmlImportPanel extends StatelessWidget {
  const AdminYmlImportPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AdminYmlImportCubit>(),
      child: const _AdminYmlImportView(),
    );
  }
}

class _AdminYmlImportView extends StatelessWidget {
  const _AdminYmlImportView();

  Future<void> _pickFile(BuildContext context) async {
    final cubit = context.read<AdminYmlImportCubit>();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xml', 'yml'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось прочитать файл')),
      );
      return;
    }

    String text;
    try {
      text = utf8.decode(bytes, allowMalformed: false);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Файл должен быть в кодировке UTF-8')),
      );
      return;
    }

    cubit.setPickedFile(
      fileName: file.name,
      fileSizeBytes: bytes.length,
      ymlText: text,
    );
  }

  Future<void> _confirmApply(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Применить импорт?'),
        content: const Text(
          'Данные из файла будут записаны в каталог. '
          'Товары не удаляются и не скрываются.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Применить'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AdminYmlImportCubit>().runLiveImport();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminYmlImportCubit, AdminYmlImportState>(
      builder: (context, state) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xxxl,
          ),
          children: [
            const Text(
              'Загрузите экспорт YML/XML из Tilda, пока публичная ссылка на фид недоступна.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _SafetyWarnings(),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: state.isBusy ? null : () => _pickFile(context),
              icon: const Icon(Icons.upload_file_outlined, size: 20),
              label: Text(
                state.fileName == null ? 'Выбрать файл' : 'Выбрать другой файл',
              ),
            ),
            if (state.fileName != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _FileInfo(
                name: state.fileName!,
                sizeBytes: state.fileSizeBytes ?? 0,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: state.canValidate
                  ? () => context.read<AdminYmlImportCubit>().runDryRun()
                  : null,
              child: state.phase == AdminYmlImportPhase.dryRunLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : const Text('Проверить файл'),
            ),
            if (state.dryRunResult != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _ResultCard(
                title: 'Результат проверки',
                result: state.dryRunResult!,
              ),
            ],
            if (state.canApply) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: state.isBusy
                    ? null
                    : () => _confirmApply(context),
                child: state.phase == AdminYmlImportPhase.liveLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Применить импорт'),
              ),
            ],
            if (state.liveResult != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _ResultCard(
                title: 'Импорт выполнен',
                result: state.liveResult!,
                showUpserted: true,
              ),
            ],
            if (state.errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                state.errorMessage!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Лимит файла: ${AdminYmlImportLimits.maxUploadBytes ~/ (1024 * 1024)} МБ',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SafetyWarnings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceDim,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Безопасный импорт',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text('• Товары не удаляются', style: _warnStyle),
          Text('• Товары не скрываются', style: _warnStyle),
          Text(
            '• Обновляются и добавляются только позиции из этого файла',
            style: _warnStyle,
          ),
        ],
      ),
    );
  }

  static const _warnStyle = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
    height: 1.35,
  );
}

class _FileInfo extends StatelessWidget {
  const _FileInfo({required this.name, required this.sizeBytes});

  final String name;
  final int sizeBytes;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$name · ${_formatSize(sizeBytes)}',
      style: const TextStyle(
        fontSize: 12,
        color: AppColors.textSecondary,
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.title,
    required this.result,
    this.showUpserted = false,
  });

  final String title;
  final AdminYmlImportResultEntity result;
  final bool showUpserted;

  @override
  Widget build(BuildContext context) {
    final y = result.yml;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _row('Статус', result.status),
          if (result.runId != null) _row('run_id', result.runId!),
          if (result.verdict != null) _row('Вердикт', result.verdict!),
          _row('Категории', '${y.categoriesCount}'),
          _row('Группы / товары', '${y.groupsCount}'),
          _row('Офферы (SKU)', '${y.offersCount}'),
          _row('Картинки в YML', '${y.imagesInYml}'),
          _row('products_seen', '${result.productsSeen}'),
          _row('variants_seen', '${result.variantsSeen}'),
          _row('images_seen', '${result.imagesSeen}'),
          if (showUpserted) ...[
            _row('products_upserted', '${result.productsUpserted}'),
            _row('variants_upserted', '${result.variantsUpserted}'),
            _row('images_upserted', '${result.imagesUpserted}'),
          ],
          _row('Ошибки', '${result.errorCount}'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
