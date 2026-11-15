import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/profile_entity.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/sign_up_outcome.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthCubitState> {
  final AccountRepository _repository;
  StreamSubscription<AuthState>? _authSub;

  AuthCubit(this._repository) : super(const AuthCubitState()) {
    _init();
  }

  void _init() {
    final user = _repository.currentUser;
    if (user != null) {
      emit(state.copyWith(status: AuthStatus.authenticated, email: user.email));
      _loadProfile();
    } else {
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }

    _authSub = _repository.authStateChanges.listen((authState) {
      final event = authState.event;
      final user = authState.session?.user;

      if (event == AuthChangeEvent.signedIn && user != null) {
        emit(
          state.copyWith(
            status: AuthStatus.authenticated,
            email: user.email,
            clearError: true,
            confirmationRequired: false,
          ),
        );
        _loadProfile();
      } else if (event == AuthChangeEvent.signedOut) {
        emit(AuthCubitState(status: AuthStatus.unauthenticated));
      }
    });
  }

  Future<void> signUp({required String email, required String password}) async {
    if (state.isLoading) return;
    emit(
      state.copyWith(
        isLoading: true,
        clearError: true,
        confirmationRequired: false,
      ),
    );
    try {
      final outcome = await _repository.signUp(
        email: email,
        password: password,
      );
      if (outcome == SignUpOutcome.confirmationRequired) {
        emit(state.copyWith(isLoading: false, confirmationRequired: true));
        return;
      }
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: _friendlyError(e),
          confirmationRequired: false,
        ),
      );
      return;
    }
    _emitAuthenticated(fallbackEmail: email);
    await _loadProfile();
  }

  Future<void> signIn({required String email, required String password}) async {
    if (state.isLoading) return;
    emit(
      state.copyWith(
        isLoading: true,
        clearError: true,
        confirmationRequired: false,
      ),
    );
    try {
      await _repository.signIn(email: email, password: password);
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: _friendlyError(e)));
      return;
    }
    _emitAuthenticated(fallbackEmail: email);
    await _loadProfile();
  }

  void _emitAuthenticated({required String fallbackEmail}) {
    final user = _repository.currentUser;
    emit(
      state.copyWith(
        status: user != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
        email: user?.email ?? fallbackEmail,
        isLoading: false,
        clearError: true,
        confirmationRequired: false,
      ),
    );
  }

  /// Hides the "confirm your email" notice and returns to the form.
  void dismissConfirmation() {
    if (!state.confirmationRequired) return;
    emit(state.copyWith(confirmationRequired: false));
  }

  Future<void> signOut() async {
    await _repository.signOut();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _repository.getProfile();
      if (profile != null && !isClosed) {
        emit(state.copyWith(profile: profile));
      }
    } catch (_) {
      // Silent on load — profile section will show empty state.
    }
  }

  /// Re-fetches the profile from the backend.
  /// Useful when the account screen becomes visible again.
  Future<void> refreshProfile() async => _loadProfile();

  /// Saves the phone from a completed order onto the signed-in profile.
  /// A guest is ignored. A failure does not change auth status or surface
  /// an error: the order has already succeeded.
  Future<void> syncSubmittedPhone(String phone) async {
    if (_repository.currentUser == null) return;
    try {
      final saved = await _repository.saveCheckoutPhone(phone);
      if (saved != null && !isClosed) {
        emit(state.copyWith(profile: saved));
      }
    } catch (_) {}
  }

  Future<void> updateProfile({
    String? name,
    String? phone,
    String? loyaltyCard,
  }) async {
    final current = state.profile;
    final userId = _repository.currentUser?.id;
    if (current == null && userId == null) return;

    final base = current ?? ProfileEntity(id: userId!);
    final updated = ProfileEntity(
      id: base.id,
      name: name ?? base.name,
      phone: phone ?? base.phone,
      loyaltyCard: loyaltyCard ?? base.loyaltyCard,
    );

    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _repository.upsertProfile(updated);
      final refreshed = await _repository.getProfile();
      emit(state.copyWith(profile: refreshed ?? updated, isLoading: false));
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Не удалось сохранить профиль: $e',
        ),
      );
    }
  }

  void clearError() {
    emit(state.copyWith(clearError: true));
  }

  String _friendlyError(Object e) {
    final code = e is AuthException ? e.code : null;
    switch (code) {
      case 'email_address_invalid':
        return 'Этот email не подходит для регистрации. Укажите другой адрес.';
      case 'invalid_credentials':
        return 'Неверный email или пароль';
      case 'email_not_confirmed':
        return 'Подтвердите email для входа';
      case 'user_already_exists':
      case 'email_exists':
        return 'Этот email уже зарегистрирован';
      case 'weak_password':
        return 'Пароль должен быть не менее 6 символов';
    }

    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid login')) return 'Неверный email или пароль';
    if (msg.contains('email not confirmed')) {
      return 'Подтвердите email для входа';
    }
    if (msg.contains('already registered') ||
        msg.contains('already been registered')) {
      return 'Этот email уже зарегистрирован';
    }
    if (msg.contains('password')) {
      return 'Пароль должен быть не менее 6 символов';
    }
    return 'Произошла ошибка. Попробуйте позже.';
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    return super.close();
  }
}
