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
    final profile = await _repository.getProfile();
    if (profile != null && !isClosed) {
      emit(state.copyWith(profile: profile));
    }
  }

  Future<void> updateProfile({
    String? name,
    String? phone,
    String? loyaltyCard,
  }) async {
    final current = state.profile;
    if (current == null) return;

    final updated = ProfileEntity(
      id: current.id,
      name: name ?? current.name,
      phone: phone ?? current.phone,
      loyaltyCard: loyaltyCard ?? current.loyaltyCard,
    );

    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _repository.upsertProfile(updated);
      emit(state.copyWith(profile: updated, isLoading: false));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Не удалось сохранить профиль',
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
