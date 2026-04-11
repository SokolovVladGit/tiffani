import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_back_button.dart';
import '../../../../core/widgets/tiffany_primary_button.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

// ---------------------------------------------------------------------------
// Public mode enum — used by router to set initial page
// ---------------------------------------------------------------------------

enum AuthShellMode { welcome, login, register }

// ---------------------------------------------------------------------------
// Shell page
// ---------------------------------------------------------------------------

class AuthShellPage extends StatefulWidget {
  final AuthShellMode initialMode;

  /// When true (default), the shell pops itself on auth success.
  /// Set to false when embedded inside a parent that reacts to auth state
  /// (e.g. AccountPage's BlocBuilder swaps the shell for the profile view).
  final bool popOnAuthSuccess;

  const AuthShellPage({
    super.key,
    this.initialMode = AuthShellMode.welcome,
    this.popOnAuthSuccess = true,
  });

  @override
  State<AuthShellPage> createState() => _AuthShellPageState();
}

class _AuthShellPageState extends State<AuthShellPage> {
  late final PageController _pageController;
  late AuthShellMode _mode;

  static const _pageDuration = Duration(milliseconds: 300);
  static const _pageCurve = Curves.easeInOut;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _pageController = PageController(initialPage: _mode.index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(AuthShellMode target) {
    FocusScope.of(context).unfocus();
    setState(() => _mode = target);
    _pageController.animateToPage(
      target.index,
      duration: _pageDuration,
      curve: _pageCurve,
    );
  }

  void _handleBack() {
    if (_mode == AuthShellMode.welcome) {
      Navigator.of(context).maybePop();
    } else {
      _goTo(AuthShellMode.welcome);
    }
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
            if (widget.popOnAuthSuccess) Navigator.of(context).maybePop();
          } else if (state.errorMessage != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(state.errorMessage!)),
              );
            sl<AuthCubit>().clearError();
          }
        },
        child: PopScope(
          canPop: _mode == AuthShellMode.welcome,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _goTo(AuthShellMode.welcome);
          },
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.dark,
            child: Scaffold(
              resizeToAvoidBottomInset: true,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/home/log_bg.jpg',
                    fit: BoxFit.cover,
                  ),
                  // Subtle top scrim for status-bar icon readability
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: MediaQuery.of(context).padding.top + 24,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x30FFFFFF),
                            Color(0x00FFFFFF),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: AppSpacing.sm,
                              top: AppSpacing.xs,
                            ),
                            child: AppBackButton(onTap: _handleBack),
                          ),
                        ),
                        Expanded(
                          child: PageView(
                            controller: _pageController,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _WelcomeContent(
                                onLogin: () => _goTo(AuthShellMode.login),
                                onRegister: () =>
                                    _goTo(AuthShellMode.register),
                              ),
                              _LoginContent(
                                onSwitchToRegister: () =>
                                    _goTo(AuthShellMode.register),
                              ),
                              _RegisterContent(
                                onSwitchToLogin: () =>
                                    _goTo(AuthShellMode.login),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared surface — subtle translucent veil behind content blocks
// ---------------------------------------------------------------------------

const _surfaceColor = Color(0x66FFFFFF);
const _surfaceRadius = AppRadius.lg;
const _surfaceBorder = BorderSide(color: Color(0x33FFFFFF), width: 0.5);
const _surfacePadding =
    EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xl);

/// Proportional top spacer that anchors content to the same vertical zone
/// across all auth modes (~35–40% of screen when at rest).
double _topSpacer(BuildContext context) =>
    MediaQuery.of(context).size.height * 0.15;

// ---------------------------------------------------------------------------
// Welcome
// ---------------------------------------------------------------------------

class _WelcomeContent extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  const _WelcomeContent({
    required this.onLogin,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          SizedBox(height: _topSpacer(context)),
          Container(
            width: double.infinity,
            padding: _surfacePadding,
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(_surfaceRadius),
              border: Border.fromBorderSide(_surfaceBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _WelcomeMonogram(),
                const SizedBox(height: AppSpacing.xl),
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
                  onPressed: onLogin,
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onRegister,
                    child: const Text('Создать аккаунт'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Login
// ---------------------------------------------------------------------------

class _LoginContent extends StatefulWidget {
  final VoidCallback onSwitchToRegister;

  const _LoginContent({required this.onSwitchToRegister});

  @override
  State<_LoginContent> createState() => _LoginContentState();
}

class _LoginContentState extends State<_LoginContent>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  bool get wantKeepAlive => true;

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
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          SizedBox(height: _topSpacer(context)),
          Container(
            width: double.infinity,
            padding: _surfacePadding,
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(_surfaceRadius),
              border: Border.fromBorderSide(_surfaceBorder),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: AppSpacing.xxl),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(hintText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Укажите email'
                            : null,
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
                    textInputAction: TextInputAction.done,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Укажите пароль' : null,
                    onFieldSubmitted: (_) => _handleLogin(),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
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
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: GestureDetector(
                      onTap: widget.onSwitchToRegister,
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
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Register
// ---------------------------------------------------------------------------

class _RegisterContent extends StatefulWidget {
  final VoidCallback onSwitchToLogin;

  const _RegisterContent({required this.onSwitchToLogin});

  @override
  State<_RegisterContent> createState() => _RegisterContentState();
}

class _RegisterContentState extends State<_RegisterContent>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _emailSent = false;
  String _sentEmail = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _handleRegister() {
    if (!_formKey.currentState!.validate()) return;
    _sentEmail = _emailCtrl.text.trim();
    sl<AuthCubit>().signUp(
      email: _sentEmail,
      password: _passwordCtrl.text,
    );
  }

  void _resetToForm() => setState(() => _emailSent = false);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocListener<AuthCubit, AuthCubitState>(
      listenWhen: (prev, curr) => prev.isLoading && !curr.isLoading,
      listener: (context, state) {
        if (!state.isAuthenticated && state.errorMessage == null) {
          setState(() => _emailSent = true);
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _emailSent
            ? _EmailConfirmationContent(
                email: _sentEmail,
                onChangeEmail: _resetToForm,
                onSwitchToLogin: widget.onSwitchToLogin,
              )
            : _buildForm(context),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      key: const ValueKey('register_form'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          SizedBox(height: _topSpacer(context)),
          Container(
            width: double.infinity,
            padding: _surfacePadding,
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(_surfaceRadius),
              border: Border.fromBorderSide(_surfaceBorder),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: AppSpacing.xxl),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(hintText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Укажите email';
                      }
                      if (!v.contains('@')) return 'Некорректный email';
                      return null;
                    },
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
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Укажите пароль';
                      if (v.length < 6) return 'Минимум 6 символов';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _confirmCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Подтвердите пароль',
                    ),
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    validator: (v) {
                      if (v != _passwordCtrl.text) {
                        return 'Пароли не совпадают';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _handleRegister(),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  BlocBuilder<AuthCubit, AuthCubitState>(
                    buildWhen: (prev, curr) =>
                        prev.isLoading != curr.isLoading,
                    builder: (context, state) {
                      return TiffanyPrimaryButton(
                        label: 'Создать аккаунт',
                        onPressed:
                            state.isLoading ? null : _handleRegister,
                        isLoading: state.isLoading,
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: GestureDetector(
                      onTap: widget.onSwitchToLogin,
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
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Email confirmation — shown after successful signUp
// ---------------------------------------------------------------------------

class _EmailConfirmationContent extends StatelessWidget {
  final String email;
  final VoidCallback onChangeEmail;
  final VoidCallback onSwitchToLogin;

  const _EmailConfirmationContent({
    required this.email,
    required this.onChangeEmail,
    required this.onSwitchToLogin,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('email_confirmation'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          SizedBox(height: _topSpacer(context)),
          Container(
            width: double.infinity,
            padding: _surfacePadding,
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(_surfaceRadius),
              border: Border.fromBorderSide(_surfaceBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.seed,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.mail_outline_rounded,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const Text(
                  'Проверьте почту',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Мы отправили ссылку для\nподтверждения аккаунта',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    email,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxxl),
                TiffanyPrimaryButton(
                  label: 'Войти',
                  onPressed: onSwitchToLogin,
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onChangeEmail,
                    child: const Text('Изменить email'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Branded monogram tile with subtle pendulum animation
// ---------------------------------------------------------------------------

class _WelcomeMonogram extends StatefulWidget {
  const _WelcomeMonogram();

  @override
  State<_WelcomeMonogram> createState() => _WelcomeMonogramState();
}

class _WelcomeMonogramState extends State<_WelcomeMonogram>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _rotation = Tween<double>(begin: -0.03, end: 0.03).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotation,
      builder: (context, child) => Transform.rotate(
        angle: _rotation.value,
        alignment: Alignment.topCenter,
        child: child,
      ),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.seed,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        alignment: Alignment.center,
        child: const Text(
          'T',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1.2,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
