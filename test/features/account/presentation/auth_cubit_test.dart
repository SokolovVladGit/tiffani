import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tiffani/features/account/domain/checkout_phone_sync.dart';
import 'package:tiffani/features/account/domain/entities/order_summary_entity.dart';
import 'package:tiffani/features/account/domain/entities/profile_entity.dart';
import 'package:tiffani/features/account/domain/repositories/account_repository.dart';
import 'package:tiffani/features/account/domain/sign_up_outcome.dart';
import 'package:tiffani/features/account/presentation/cubit/auth_cubit.dart';
import 'package:tiffani/features/account/presentation/cubit/auth_state.dart';

User _user({String email = 'a@b.co'}) {
  return User(
    id: 'user-1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    email: email,
    createdAt: '2026-01-01T00:00:00Z',
  );
}

class _FakeAccountRepository implements AccountRepository {
  User? user;
  SignUpOutcome outcome = SignUpOutcome.session;
  Object? signUpError;
  Object? signInError;
  Object? profileError;
  ProfileEntity? profile;
  Future<SignUpOutcome>? signUpGate;

  int signUpCalls = 0;
  int signInCalls = 0;
  int profileLoads = 0;
  int phoneWrites = 0;
  Object? phoneSyncError;
  String? lastEmail;
  final List<OrderSummaryEntity> orders = [
    OrderSummaryEntity(
      id: 'order-1',
      createdAt: DateTime.utc(2026, 11, 15),
      totalItems: 1,
      totalQuantity: 1,
      totalPrice: 10,
      status: 'new',
    ),
  ];

  final _auth = StreamController<AuthState>.broadcast();

  @override
  Stream<AuthState> get authStateChanges => _auth.stream;

  @override
  User? get currentUser => user;

  @override
  bool get isAuthenticated => user != null;

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  }) async {
    signUpCalls++;
    lastEmail = email;
    final gate = signUpGate;
    final result = gate == null ? outcome : await gate;
    if (signUpError != null) throw signUpError!;
    if (result == SignUpOutcome.session) {
      user = _user(email: email);
    }
    return result;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
    if (signInError != null) throw signInError!;
    user = _user(email: email);
  }

  @override
  Future<void> signOut() async {
    user = null;
    _auth.add(const AuthState(AuthChangeEvent.signedOut, null));
  }

  @override
  Future<ProfileEntity?> getProfile() async {
    profileLoads++;
    if (profileError != null) throw profileError!;
    if (profile != null) return profile;
    final current = user;
    if (current == null) return null;
    return ProfileEntity(id: current.id);
  }

  @override
  Future<void> upsertProfile(ProfileEntity profile) async {}

  @override
  Future<ProfileEntity?> saveCheckoutPhone(String phone) async {
    if (user == null) return null;
    if (phoneSyncError != null) throw phoneSyncError!;
    final next = profileAfterCheckoutPhone(
      userId: user!.id,
      existing: profile,
      submittedPhone: phone,
    );
    if (next == null) return profile ?? ProfileEntity(id: user!.id);
    phoneWrites++;
    profile = next;
    return next;
  }

  @override
  Future<List<OrderSummaryEntity>> getOrderHistory() async => orders;

  Future<void> close() => _auth.close();
}

void main() {
  late _FakeAccountRepository repo;
  late AuthCubit cubit;

  setUp(() {
    repo = _FakeAccountRepository();
    cubit = AuthCubit(repo);
  });

  tearDown(() async {
    await cubit.close();
    await repo.close();
  });

  test('sign-up with a session authenticates and loads the profile', () async {
    repo.profile = const ProfileEntity(id: 'user-1', name: 'Анна');

    await cubit.signUp(email: ' a@b.co ', password: 'secret1');

    expect(cubit.state.status, AuthStatus.authenticated);
    expect(cubit.state.email, ' a@b.co ');
    expect(cubit.state.profile?.name, 'Анна');
    expect(cubit.state.confirmationRequired, isFalse);
    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.errorMessage, isNull);
    expect(repo.lastEmail, ' a@b.co ');
    expect(repo.profileLoads, 1);
  });

  test(
    'sign-up without a session asks for confirmation and does not log in',
    () async {
      repo.outcome = SignUpOutcome.confirmationRequired;

      await cubit.signUp(email: 'a@b.co', password: 'secret1');

      expect(cubit.state.isAuthenticated, isFalse);
      expect(cubit.state.confirmationRequired, isTrue);
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.errorMessage, isNull);
      expect(repo.profileLoads, 0);
    },
  );

  test(
    'registration API failure stays signed out and keeps a readable error',
    () async {
      repo.signUpError = Exception('already been registered');

      await cubit.signUp(email: 'a@b.co', password: 'secret1');

      expect(cubit.state.isAuthenticated, isFalse);
      expect(cubit.state.confirmationRequired, isFalse);
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.errorMessage, 'Этот email уже зарегистрирован');
    },
  );

  test(
    'email_address_invalid stays on the form with a specific message',
    () async {
      repo.signUpError = AuthApiException(
        'Email address "buyer@example.com" is invalid',
        statusCode: '400',
        code: 'email_address_invalid',
      );

      await cubit.signUp(email: 'buyer@example.com', password: 'secret1');

      expect(cubit.state.isAuthenticated, isFalse);
      expect(cubit.state.confirmationRequired, isFalse);
      expect(cubit.state.isLoading, isFalse);
      expect(
        cubit.state.errorMessage,
        'Этот email не подходит для регистрации. Укажите другой адрес.',
      );
    },
  );

  test('known auth codes and unknown failures keep their messages', () async {
    repo.signUpError = const AuthException(
      'Invalid login credentials',
      statusCode: '400',
      code: 'invalid_credentials',
    );
    await cubit.signUp(email: 'a@b.co', password: 'secret1');
    expect(cubit.state.errorMessage, 'Неверный email или пароль');
    expect(cubit.state.isLoading, isFalse);

    repo.signUpError = AuthApiException(
      'User already registered',
      statusCode: '422',
      code: 'user_already_exists',
    );
    await cubit.signUp(email: 'a@b.co', password: 'secret1');
    expect(cubit.state.errorMessage, 'Этот email уже зарегистрирован');

    repo.signUpError = AuthApiException(
      'unexpected upstream failure',
      statusCode: '500',
      code: 'unexpected_failure',
    );
    await cubit.signUp(email: 'a@b.co', password: 'secret1');
    expect(cubit.state.errorMessage, 'Произошла ошибка. Попробуйте позже.');
    expect(cubit.state.isAuthenticated, isFalse);
    expect(cubit.state.isLoading, isFalse);
  });

  test('a second sign-up is ignored while the first is pending', () async {
    final gate = Completer<SignUpOutcome>();
    repo.signUpGate = gate.future;

    final first = cubit.signUp(email: 'a@b.co', password: 'secret1');
    final second = cubit.signUp(email: 'a@b.co', password: 'secret1');
    gate.complete(SignUpOutcome.session);
    await Future.wait([first, second]);

    expect(repo.signUpCalls, 1);
    expect(cubit.state.isAuthenticated, isTrue);
  });

  test('profile load failure does not revoke the new session', () async {
    repo.profileError = Exception('permission denied');

    await cubit.signUp(email: 'a@b.co', password: 'secret1');

    expect(cubit.state.status, AuthStatus.authenticated);
    expect(cubit.state.errorMessage, isNull);
    expect(cubit.state.isLoading, isFalse);
  });

  test('login success and bad credentials', () async {
    repo.profile = const ProfileEntity(id: 'user-1', phone: '+373');

    await cubit.signIn(email: 'a@b.co', password: 'secret1');

    expect(cubit.state.isAuthenticated, isTrue);
    expect(cubit.state.profile?.phone, '+373');
    expect(cubit.state.errorMessage, isNull);

    await cubit.signOut();
    expect(cubit.state.status, AuthStatus.unauthenticated);
    expect(cubit.state.profile, isNull);

    repo.signInError = Exception('Invalid login credentials');
    await cubit.signIn(email: 'a@b.co', password: 'wrong');

    expect(cubit.state.isAuthenticated, isFalse);
    expect(cubit.state.errorMessage, 'Неверный email или пароль');
    expect(cubit.state.isLoading, isFalse);
  });

  test('existing session is restored and the profile is loaded', () async {
    await cubit.close();
    repo.user = _user();
    repo.profile = const ProfileEntity(id: 'user-1', name: 'Анна');
    cubit = AuthCubit(repo);
    await pumpEventQueue();

    expect(cubit.state.status, AuthStatus.authenticated);
    expect(cubit.state.email, 'a@b.co');
    expect(cubit.state.profile?.name, 'Анна');
  });
}
