import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/discount_campaign_entity.dart';
import '../../domain/entities/discount_campaign_target_entity.dart';
import '../cubit/admin_discounts_cubit.dart';
import '../cubit/admin_discounts_state.dart';
import '../widgets/admin_campaign_card.dart';
import 'admin_campaign_edit_sheet.dart';

/// Top-level admin discount/promocode management surface.
///
/// Embedded into the Account/Profile screen for users who pass the
/// `public.is_admin()` check. The widget owns its own [BlocProvider] so it
/// can be safely dropped into any place in the widget tree.
class AdminPanelPage extends StatelessWidget {
  const AdminPanelPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AdminDiscountsCubit>(),
      child: const _AdminPanelView(),
    );
  }
}

enum _AdminTab { promocodes, automatics }

class _AdminPanelView extends StatefulWidget {
  const _AdminPanelView();

  @override
  State<_AdminPanelView> createState() => _AdminPanelViewState();
}

class _AdminPanelViewState extends State<_AdminPanelView> {
  _AdminTab _tab = _AdminTab.promocodes;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<AdminDiscountsCubit>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      cubit.loadPromocodes();
      cubit.loadAutomatics();
    });
  }

  void _switchTab(_AdminTab tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
  }

  Future<void> _onCreate() async {
    final cubit = context.read<AdminDiscountsCubit>();
    final initial = _tab == _AdminTab.promocodes
        ? const DiscountCampaignEntity(
            kind: DiscountCampaignKind.promocode,
            name: '',
            percentOff: 0,
          )
        : const DiscountCampaignEntity(
            kind: DiscountCampaignKind.automatic,
            name: '',
            percentOff: 0,
            targets: [
              DiscountCampaignTargetEntity(
                targetType: DiscountTargetType.all,
                matchMode: DiscountTargetMatchMode.exact,
              ),
            ],
          );

    final saved = await AdminCampaignEditSheet.show(
      context,
      cubit: cubit,
      initial: initial,
    );
    if (saved != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Сохранено')));
    }
  }

  Future<void> _onEdit(DiscountCampaignEntity campaign) async {
    final cubit = context.read<AdminDiscountsCubit>();
    final saved = await AdminCampaignEditSheet.show(
      context,
      cubit: cubit,
      initial: campaign,
    );
    if (saved != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Сохранено')));
    }
  }

  Future<void> _onToggleActive(DiscountCampaignEntity campaign) async {
    await context.read<AdminDiscountsCubit>().setActive(
      campaign,
      !campaign.isActive,
      onError: (msg) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(msg)));
      },
    );
  }

  Future<void> _refresh() async {
    final cubit = context.read<AdminDiscountsCubit>();
    if (_tab == _AdminTab.promocodes) {
      await cubit.loadPromocodes(force: true);
    } else {
      await cubit.loadAutomatics(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminDiscountsCubit, AdminDiscountsState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TabSwitcher(
              tab: _tab,
              onChanged: _switchTab,
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _tab == _AdminTab.promocodes
                          ? 'Управление промокодами'
                          : 'Автоматические скидки',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _onCreate,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Создать'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: _buildList(state),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildList(AdminDiscountsState state) {
    final isPromo = _tab == _AdminTab.promocodes;
    final status = isPromo ? state.promocodesStatus : state.automaticsStatus;
    final items = isPromo ? state.promocodes : state.automatics;
    final error = isPromo ? state.promocodesError : state.automaticsError;

    if (status == AdminListStatus.loading && items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: CircularProgressIndicator.adaptive(),
        ),
      );
    }

    if (status == AdminListStatus.error && items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _ErrorPlaceholder(
            message: error ?? 'Не удалось загрузить данные',
            onRetry: _refresh,
          ),
        ],
      );
    }

    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _EmptyPlaceholder(isPromo: isPromo, onCreate: _onCreate),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final c = items[index];
        final mutating = c.id != null && state.mutatingIds.contains(c.id);
        return AdminCampaignCard(
          campaign: c,
          isMutating: mutating,
          onEdit: () => _onEdit(c),
          onToggleActive: () => _onToggleActive(c),
        );
      },
    );
  }
}

class _TabSwitcher extends StatelessWidget {
  final _AdminTab tab;
  final ValueChanged<_AdminTab> onChanged;
  const _TabSwitcher({required this.tab, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceDim,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            _SegmentButton(
              label: 'Скидки',
              selected: tab == _AdminTab.automatics,
              onTap: () => onChanged(_AdminTab.automatics),
            ),
            _SegmentButton(
              label: 'Промокоды',
              selected: tab == _AdminTab.promocodes,
              onTap: () => onChanged(_AdminTab.promocodes),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color:
                  selected ? AppColors.textPrimary : AppColors.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  final bool isPromo;
  final VoidCallback onCreate;
  const _EmptyPlaceholder({required this.isPromo, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Icon(
            isPromo
                ? Icons.local_offer_outlined
                : Icons.discount_outlined,
            size: 32,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            isPromo ? 'Промокодов пока нет' : 'Скидок пока нет',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isPromo
                ? 'Создайте первый промокод, чтобы начать его использовать в заказах.'
                : 'Создайте автоматическую скидку — она будет применяться к подходящим заказам.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Создать'),
          ),
        ],
      ),
    );
  }
}

class _ErrorPlaceholder extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorPlaceholder({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline,
            size: 28,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}
