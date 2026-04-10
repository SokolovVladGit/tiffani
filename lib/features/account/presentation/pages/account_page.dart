import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/tiffany_primary_button.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<AuthCubit>(),
      child: Scaffold(
        appBar: AppBar(
          leading: const Center(child: AppBackButton()),
          title: const Text('Личный кабинет'),
        ),
        body: BlocBuilder<AuthCubit, AuthCubitState>(
          builder: (context, state) {
            if (state.isAuthenticated) {
              return _AuthenticatedView(state: state);
            }
            return const _GuestView();
          },
        ),
      ),
    );
  }
}

// =============================================================================
// Guest view
// =============================================================================

class _GuestView extends StatelessWidget {
  const _GuestView();

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
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.surfaceDim,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 32,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              const Text(
                'Войдите или создайте аккаунт',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Для сохранения данных\nи просмотра истории заказов',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              TiffanyPrimaryButton(
                label: 'Войти',
                onPressed: () => context.push(RouteNames.login),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.push(RouteNames.register),
                  child: const Text('Создать аккаунт'),
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
// Authenticated view
// =============================================================================

class _AuthenticatedView extends StatefulWidget {
  final AuthCubitState state;

  const _AuthenticatedView({required this.state});

  @override
  State<_AuthenticatedView> createState() => _AuthenticatedViewState();
}

class _AuthenticatedViewState extends State<_AuthenticatedView> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _loyaltyCtrl;

  @override
  void initState() {
    super.initState();
    final p = widget.state.profile;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _phoneCtrl = TextEditingController(text: p?.phone ?? '');
    _loyaltyCtrl = TextEditingController(text: p?.loyaltyCard ?? '');
  }

  @override
  void didUpdateWidget(covariant _AuthenticatedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final p = widget.state.profile;
    if (p != oldWidget.state.profile && p != null) {
      _nameCtrl.text = p.name ?? '';
      _phoneCtrl.text = p.phone ?? '';
      _loyaltyCtrl.text = p.loyaltyCard ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _loyaltyCtrl.dispose();
    super.dispose();
  }

  void _handleSave() {
    sl<AuthCubit>().updateProfile(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      loyaltyCard: _loyaltyCtrl.text.trim(),
    );
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Данные сохранены')),
      );
  }

  void _handleLogout() {
    sl<AuthCubit>().signOut();
    if (context.mounted) {
      context.go(RouteNames.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      children: [
        // Email (read-only)
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: AppDecorations.cardSoft(radius: AppRadius.lg),
          child: Row(
            children: [
              const Icon(
                Icons.email_outlined,
                size: 20,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Email',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.state.email ?? '—',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Order history
        GestureDetector(
          onTap: () => context.push(RouteNames.orderHistory),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: AppDecorations.cardSoft(radius: AppRadius.lg),
            child: Row(
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: Text(
                    'История заказов',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Editable fields
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: AppDecorations.cardSoft(radius: AppRadius.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Личные данные',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
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
                onFieldSubmitted: (_) => _handleSave(),
              ),
              const SizedBox(height: AppSpacing.xl),
              BlocBuilder<AuthCubit, AuthCubitState>(
                buildWhen: (prev, curr) =>
                    prev.isLoading != curr.isLoading,
                builder: (context, state) {
                  return TiffanyPrimaryButton(
                    label: 'Сохранить',
                    onPressed: state.isLoading ? null : _handleSave,
                    isLoading: state.isLoading,
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxxl),

        // Logout
        Center(
          child: GestureDetector(
            onTap: _handleLogout,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                'Выйти из аккаунта',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
