import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/tiffany_primary_button.dart';
import '../../domain/entities/order_summary_entity.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/repositories/account_repository.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';
import 'auth_shell_page.dart';

/// Shared background asset for account-area screens.
const accountBgAsset = 'assets/images/home/acc_bg.jpg';

/// Card surface used over the background.
BoxDecoration accountCardDecoration() => BoxDecoration(
      color: AppColors.surface.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(
        color: AppColors.border.withValues(alpha: 0.35),
        width: 0.5,
      ),
    );

// =============================================================================
// Account page — auth gate + account shell
// =============================================================================

class AccountPage extends StatelessWidget {
  /// When true the shell opens directly on order history.
  final bool showOrderHistory;

  const AccountPage({super.key, this.showOrderHistory = false});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<AuthCubit>(),
      child: BlocBuilder<AuthCubit, AuthCubitState>(
        builder: (context, state) {
          if (!state.isAuthenticated) {
            return const AuthShellPage(popOnAuthSuccess: false);
          }
          return _AccountShell(
            state: state,
            showOrderHistory: showOrderHistory,
          );
        },
      ),
    );
  }
}

// =============================================================================
// Account shell — fixed background + internal section switching
// =============================================================================

enum _Section { main, orderHistory }

class _AccountShell extends StatefulWidget {
  final AuthCubitState state;
  final bool showOrderHistory;

  const _AccountShell({
    required this.state,
    this.showOrderHistory = false,
  });

  @override
  State<_AccountShell> createState() => _AccountShellState();
}

class _AccountShellState extends State<_AccountShell> {
  late _Section _section;

  @override
  void initState() {
    super.initState();
    _section =
        widget.showOrderHistory ? _Section.orderHistory : _Section.main;
    sl<AuthCubit>().refreshProfile();
  }

  void _openOrders() => setState(() => _section = _Section.orderHistory);
  void _backToMain() => setState(() => _section = _Section.main);

  void _handleBack() {
    if (_section == _Section.orderHistory) {
      _backToMain();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  String get _title => switch (_section) {
        _Section.main => 'Личный кабинет',
        _Section.orderHistory => 'История заказов',
      };

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthCubitState>(
      listenWhen: (prev, curr) =>
          prev.errorMessage != curr.errorMessage &&
          curr.errorMessage != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        sl<AuthCubit>().clearError();
      },
      child: PopScope(
        canPop: _section == _Section.main,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _backToMain();
        },
        child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          leading: Center(child: AppBackButton(onTap: _handleBack)),
          title: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _title,
              key: ValueKey(_title),
            ),
          ),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(accountBgAsset, fit: BoxFit.cover),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                final isIncoming =
                    child.key == ValueKey(_section);
                final offset = Tween<Offset>(
                  begin: Offset(isIncoming ? 0.15 : -0.15, 0),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: offset,
                    child: child,
                  ),
                );
              },
              child: _section == _Section.main
                  ? _AccountMainContent(
                      key: const ValueKey(_Section.main),
                      state: widget.state,
                      onOpenOrders: _openOrders,
                    )
                  : _OrderHistoryContent(
                      key: const ValueKey(_Section.orderHistory),
                    ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

// =============================================================================
// Account main content
// =============================================================================

class _AccountMainContent extends StatelessWidget {
  final AuthCubitState state;
  final VoidCallback onOpenOrders;

  const _AccountMainContent({
    super.key,
    required this.state,
    required this.onOpenOrders,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        topPad + AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      children: [
        // ── Identity ──
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          decoration: accountCardDecoration(),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.seed,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initialLetter(state.email),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Аккаунт',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: AppColors.textTertiary.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.email ?? '—',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // ── Order history entry ──
        GestureDetector(
          onTap: onOpenOrders,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            decoration: accountCardDecoration(),
            child: const Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'История заказов',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // ── Personal data (display ↔ edit) ──
        BlocBuilder<AuthCubit, AuthCubitState>(
          buildWhen: (prev, curr) =>
              prev.profile != curr.profile ||
              prev.isLoading != curr.isLoading,
          builder: (context, s) =>
              _ProfileSection(profile: s.profile, isLoading: s.isLoading),
        ),
        const SizedBox(height: AppSpacing.xxxl),

        // ── Logout ──
        Center(
          child: GestureDetector(
            onTap: () {
              sl<AuthCubit>().signOut();
              if (context.mounted) context.go(RouteNames.home);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.textTertiary.withValues(alpha: 0.4),
                ),
              ),
              child: const Text(
                'Выйти из аккаунта',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  static String _initialLetter(String? email) {
    if (email == null || email.isEmpty) return '?';
    return email[0].toUpperCase();
  }
}

// =============================================================================
// Profile section — display ↔ edit
// =============================================================================

class _ProfileSection extends StatefulWidget {
  final ProfileEntity? profile;
  final bool isLoading;

  const _ProfileSection({required this.profile, required this.isLoading});

  @override
  State<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  bool _editing = false;
  bool _savePending = false;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _loyaltyCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _loyaltyCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _loyaltyCtrl.dispose();
    super.dispose();
  }

  void _enterEdit() {
    final p = widget.profile;
    _nameCtrl.text = p?.name ?? '';
    _phoneCtrl.text = p?.phone ?? '';
    _loyaltyCtrl.text = p?.loyaltyCard ?? '';
    setState(() => _editing = true);
  }

  void _cancelEdit() {
    FocusScope.of(context).unfocus();
    setState(() => _editing = false);
  }

  void _saveEdit() {
    FocusScope.of(context).unfocus();
    setState(() => _savePending = true);
    sl<AuthCubit>().updateProfile(
      name: _nullIfBlank(_nameCtrl.text),
      phone: _nullIfBlank(_phoneCtrl.text),
      loyaltyCard: _nullIfBlank(_loyaltyCtrl.text),
    );
  }

  /// Returns null for blank input so the cubit's fallback to current value
  /// preserves existing data when the user leaves a field empty.
  static String? _nullIfBlank(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool get _hasAnyData {
    final p = widget.profile;
    if (p == null) return false;
    return _filled(p.name) || _filled(p.phone) || _filled(p.loyaltyCard);
  }

  static bool _filled(String? v) => v != null && v.trim().isNotEmpty;

  void _onAuthStateChanged(BuildContext context, AuthCubitState state) {
    if (!_savePending) return;
    if (state.isLoading) return;
    _savePending = false;
    if (state.errorMessage != null) return;
    setState(() => _editing = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Данные сохранены')));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthCubitState>(
      listenWhen: (prev, curr) =>
          _savePending && prev.isLoading && !curr.isLoading,
      listener: _onAuthStateChanged,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: accountCardDecoration(),
          child: _editing ? _buildEdit() : _buildDisplay(),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Display mode
  // ---------------------------------------------------------------------------

  Widget _buildDisplay() {
    if (!_hasAnyData) return _buildEmpty();

    final p = widget.profile!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Личные данные',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            GestureDetector(
              onTap: _enterEdit,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Text(
                  'Изменить',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.action,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _ProfileRow(label: 'Имя', value: p.name),
        const _RowDivider(),
        _ProfileRow(label: 'Телефон', value: p.phone),
        const _RowDivider(),
        _ProfileRow(label: 'Карта клиента', value: p.loyaltyCard),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------------------

  Widget _buildEmpty() {
    return Column(
      children: [
        const Text(
          'Личные данные',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          'Добавьте имя, телефон и номер карты клиента для удобного оформления заказов',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textTertiary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _enterEdit,
            child: const Text('Заполнить'),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Edit mode
  // ---------------------------------------------------------------------------

  Widget _buildEdit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Личные данные',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextFormField(
          controller: _nameCtrl,
          decoration: const InputDecoration(hintText: 'Имя'),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _phoneCtrl,
          decoration: const InputDecoration(hintText: 'Телефон'),
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _loyaltyCtrl,
          decoration: const InputDecoration(
            hintText: 'Номер карты клиента',
          ),
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _saveEdit(),
        ),
        const SizedBox(height: AppSpacing.xl),
        TiffanyPrimaryButton(
          label: 'Сохранить',
          onPressed: widget.isLoading ? null : _saveEdit,
          isLoading: widget.isLoading,
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: widget.isLoading ? null : _cancelEdit,
            child: const Text(
              'Отмена',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Profile display helpers
// =============================================================================

class _ProfileRow extends StatelessWidget {
  final String label;
  final String? value;

  const _ProfileRow({required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              hasValue ? value! : 'Не указано',
              style: TextStyle(
                fontSize: 15,
                fontWeight: hasValue ? FontWeight.w500 : FontWeight.w400,
                color: hasValue
                    ? AppColors.textPrimary
                    : AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: AppColors.border.withValues(alpha: 0.45),
    );
  }
}

// =============================================================================
// Order history content
// =============================================================================

class _OrderHistoryContent extends StatefulWidget {
  const _OrderHistoryContent({super.key});

  @override
  State<_OrderHistoryContent> createState() => _OrderHistoryContentState();
}

class _OrderHistoryContentState extends State<_OrderHistoryContent> {
  late Future<List<OrderSummaryEntity>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = sl<AccountRepository>().getOrderHistory();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight;

    return FutureBuilder<List<OrderSummaryEntity>>(
      future: _ordersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator.adaptive(),
          );
        }

        final orders = snapshot.data ?? [];

        if (orders.isEmpty) {
          return const _OrdersEmptyState();
        }

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            topPad + AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xxxl,
          ),
          itemCount: orders.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) =>
              _OrderCard(order: orders[index]),
        );
      },
    );
  }
}

// =============================================================================
// Order history — supporting widgets
// =============================================================================

class _OrdersEmptyState extends StatelessWidget {
  const _OrdersEmptyState();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceDim,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  size: 28,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const Text(
                'Заказов пока нет',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Оформленные заказы появятся здесь',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderSummaryEntity order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: accountCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatDate(order.createdAt),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _StatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${order.totalItems} поз. · ${order.totalQuantity} шт.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                PriceFormatter.formatRub(order.totalPrice),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day.$month.$year, $hour:$minute';
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final style = _badgeStyle;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(6),
        border: style.outlined
            ? Border.all(color: AppColors.border, width: 1)
            : null,
      ),
      child: Text(
        _localizedStatus,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: style.foreground,
        ),
      ),
    );
  }

  String get _localizedStatus {
    switch (status) {
      case 'new':
        return 'Новый';
      case 'processing':
        return 'В обработке';
      case 'confirmed':
        return 'Подтверждён';
      case 'completed':
        return 'Завершён';
      case 'cancelled':
        return 'Отменён';
      default:
        return status;
    }
  }

  _BadgeStyle get _badgeStyle {
    switch (status) {
      case 'new':
        return _BadgeStyle(
          AppColors.surfaceDim, AppColors.textSecondary,
          outlined: true,
        );
      case 'processing':
        return _BadgeStyle(AppColors.surfaceDim, AppColors.textSecondary);
      case 'confirmed':
        return _BadgeStyle(
          AppColors.textPrimary.withValues(alpha: 0.10),
          AppColors.textPrimary,
        );
      case 'completed':
        return _BadgeStyle(AppColors.textPrimary, AppColors.surface);
      case 'cancelled':
        return _BadgeStyle(AppColors.surfaceDim, AppColors.textTertiary);
      default:
        return _BadgeStyle(AppColors.surfaceDim, AppColors.textSecondary);
    }
  }
}

class _BadgeStyle {
  final Color background;
  final Color foreground;
  final bool outlined;
  const _BadgeStyle(this.background, this.foreground, {this.outlined = false});
}
