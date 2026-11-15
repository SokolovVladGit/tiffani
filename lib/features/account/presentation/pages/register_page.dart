import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/tiffany_primary_button.dart';
import '../auth_form_validators.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _handleRegister() {
    if (!_formKey.currentState!.validate()) return;
    sl<AuthCubit>().signUp(
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
              ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
            sl<AuthCubit>().clearError();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            leading: const Center(child: AppBackButton()),
            title: const Text('Регистрация'),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.xxl),
                      const Text(
                        'Создайте аккаунт',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Для сохранения данных и истории заказов',
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
                        textCapitalization: TextCapitalization.none,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.email],
                        validator: validateRegistrationEmail,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        controller: _passwordCtrl,
                        decoration: InputDecoration(
                          hintText: 'Пароль',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textTertiary,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        obscureText: _obscure,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: validateRegistrationPassword,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        controller: _confirmCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Подтвердите пароль',
                        ),
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: (v) =>
                            validatePasswordConfirmation(v, _passwordCtrl.text),
                        onFieldSubmitted: (_) => _handleRegister(),
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
                      BlocBuilder<AuthCubit, AuthCubitState>(
                        buildWhen: (prev, curr) =>
                            prev.isLoading != curr.isLoading ||
                            prev.confirmationRequired !=
                                curr.confirmationRequired,
                        builder: (context, state) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (state.confirmationRequired) ...[
                                const Text(
                                  'Аккаунт создан, но сервер не выдал сессию. '
                                  'Подтвердите email по ссылке из письма, '
                                  'затем войдите. Повторная регистрация не нужна.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                              ],
                              TiffanyPrimaryButton(
                                label: 'Создать аккаунт',
                                onPressed:
                                    state.isLoading ||
                                        state.confirmationRequired
                                    ? null
                                    : _handleRegister,
                                isLoading: state.isLoading,
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Center(
                        child: GestureDetector(
                          onTap: () => context.go(RouteNames.login),
                          child: const Text.rich(
                            TextSpan(
                              text: 'Уже есть аккаунт? ',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Войти',
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
      ),
    );
  }
}
