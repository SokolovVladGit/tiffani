import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/tiffany_primary_button.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (!_formKey.currentState!.validate()) return;
    sl<AuthCubit>().signIn(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<AuthCubit>(),
      child: BlocListener<AuthCubit, AuthCubitState>(
        listenWhen: (prev, curr) =>
            (!prev.isAuthenticated && curr.isAuthenticated) ||
            (prev.errorMessage != curr.errorMessage &&
                curr.errorMessage != null),
        listener: (context, state) {
          if (state.isAuthenticated) {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go(RouteNames.account);
            }
          } else if (state.errorMessage != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(state.errorMessage!)),
              );
            sl<AuthCubit>().clearError();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            leading: const Center(child: AppBackButton()),
            title: const Text('Вход'),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.xxl),
                    const Text(
                      'Войдите в аккаунт',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Используйте email и пароль',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(hintText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Укажите email' : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _passwordCtrl,
                      decoration: InputDecoration(
                        hintText: 'Пароль',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AppColors.textTertiary,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Укажите пароль' : null,
                      onFieldSubmitted: (_) => _handleLogin(),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                    BlocBuilder<AuthCubit, AuthCubitState>(
                      buildWhen: (prev, curr) =>
                          prev.isLoading != curr.isLoading,
                      builder: (context, state) {
                        return TiffanyPrimaryButton(
                          label: 'Войти',
                          onPressed: state.isLoading ? null : _handleLogin,
                          isLoading: state.isLoading,
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Center(
                      child: GestureDetector(
                        onTap: () => context.go(RouteNames.register),
                        child: const Text.rich(
                          TextSpan(
                            text: 'Нет аккаунта? ',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                            children: [
                              TextSpan(
                                text: 'Создать',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
