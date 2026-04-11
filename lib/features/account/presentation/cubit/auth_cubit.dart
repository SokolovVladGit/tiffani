import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/profile_entity.dart';
import '../../domain/repositories/account_repository.dart';
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
      emit(state.copyWith(
        status: AuthStatus.authenticated,
        email: user.email,
      ));
      _loadProfile();
    } else {
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }

    _authSub = _repository.authStateChanges.listen((authState) {
      final event = authState.event;
      final user = authState.session?.user;

      if (event == AuthChangeEvent.signedIn && user != null) {
        emit(state.copyWith(
          status: AuthStatus.authenticated,
          email: user.email,
          clearError: true,
        ));
        _loadProfile();
      } else if (event == AuthChangeEvent.signedOut) {
        emit(AuthCubitState(status: AuthStatus.unauthenticated));
      }
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _repository.signUp(email: email, password: password);
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: _friendlyError(e),
      ));
      return;
    }
    emit(state.copyWith(isLoading: false));
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _repository.signIn(email: email, password: password);
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: _friendlyError(e),
      ));
      return;
    }
    emit(state.copyWith(isLoading: false));
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
      emit(state.copyWith(
        profile: refreshed ?? updated,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Не удалось сохранить профиль: $e',
      ));
    }
  }

  void clearError() {
    emit(state.copyWith(clearError: true));
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('invalid login')) return 'Неверный email или пароль';
    if (msg.contains('email not confirmed')) {
      return 'Подтвердите email для входа';
    }
    if (msg.contains('already registered') || msg.contains('already been registered')) {
      return 'Этот email уже зарегистрирован';
    }
    if (msg.contains('password')) return 'Пароль должен быть не менее 6 символов';
    return 'Произошла ошибка. Попробуйте позже.';
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    return super.close();
  }
}
