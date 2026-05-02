import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../domain/entities/discount_campaign_entity.dart';
import 'admin_form_helpers.dart';

/// Compact list card used by both Промокоды and Скидки tabs.
class AdminCampaignCard extends StatelessWidget {
  final DiscountCampaignEntity campaign;
  final bool isMutating;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  const AdminCampaignCard({
    super.key,
    required this.campaign,
    required this.isMutating,
    required this.onEdit,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final isPromo = campaign.isPromocode;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status + name ──
          Row(
            children: [
              _StatusChip(active: campaign.isActive),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  campaign.name.isEmpty ? '—' : campaign.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _formatPercent(campaign.percentOff),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),

          // ── Code (promo only) ──
          if (isPromo && (campaign.code ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(
                  Icons.local_offer_outlined,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  campaign.code!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ],

          // ── Targets summary (automatic only) ──
          if (!isPromo) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _formatTargets(campaign),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ],

          // ── Description ──
          if ((campaign.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              campaign.description!.trim(),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: AppSpacing.md),
          const Divider(
            height: 1,
            thickness: 0.5,
            color: AppColors.border,
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Stats row ──
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: 6,
            children: [
              _StatLine(
                icon: Icons.date_range_outlined,
                label: _formatPeriod(campaign),
              ),
              if (campaign.minOrderAmount > 0)
                _StatLine(
                  icon: Icons.shopping_basket_outlined,
                  label: 'мин. заказ ${PriceFormatter.formatRub(campaign.minOrderAmount)}',
                ),
              _StatLine(
                icon: Icons.bar_chart,
                label: _formatUsage(campaign),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Actions ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isMutating ? null : onEdit,
                  child: const Text('Редактировать'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: isMutating ? null : onToggleActive,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: campaign.isActive
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                  child: isMutating
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(campaign.isActive ? 'Выключить' : 'Включить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatPercent(double percent) {
    if (percent == percent.roundToDouble()) {
      return '${percent.toInt()}%';
    }
    return '${percent.toStringAsFixed(1)}%';
  }

  static String _formatPeriod(DiscountCampaignEntity c) {
    final hasStart = c.startsAt != null;
    final hasEnd = c.endsAt != null;
    if (!hasStart && !hasEnd) return 'без ограничений по сроку';
    final start = formatAdminDateShort(c.startsAt);
    final end = formatAdminDateShort(c.endsAt);
    if (hasStart && hasEnd) return 'с $start по $end';
    if (hasStart) return 'с $start';
    return 'до $end';
  }

  static String _formatUsage(DiscountCampaignEntity c) {
    final used = c.usedCount;
    final max = c.maxRedemptions;
    if (max == null) return 'использовано: $used';
    return 'использовано: $used / $max';
  }

  static String _formatTargets(DiscountCampaignEntity c) {
    if (c.targets.isEmpty) return 'Условия не заданы';
    if (c.targets.length == 1) {
      return 'Условие: ${c.targets.first.summaryLabel}';
    }
    final summaries = c.targets.map((t) => t.summaryLabel).join(' • ');
    return 'Условия: $summaries';
  }
}

class _StatusChip extends StatelessWidget {
  final bool active;
  const _StatusChip({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? AppColors.textPrimary : AppColors.surfaceDim,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        active ? 'Активна' : 'Выключена',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: active ? AppColors.surface : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatLine({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textTertiary),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
