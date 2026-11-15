import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tiffani/core/di/injector.dart';
import 'package:tiffani/core/widgets/tiffany_primary_button.dart';
import 'package:tiffani/features/account/domain/entities/order_summary_entity.dart';
import 'package:tiffani/features/account/domain/entities/profile_entity.dart';
import 'package:tiffani/features/account/domain/repositories/account_repository.dart';
import 'package:tiffani/features/account/domain/sign_up_outcome.dart';
import 'package:tiffani/features/account/presentation/cubit/auth_cubit.dart';
import 'package:tiffani/features/account/presentation/pages/auth_shell_page.dart';

class _FakeAccountRepository implements AccountRepository {
  SignUpOutcome outcome = SignUpOutcome.session;
  Object? signUpError;
  Future<SignUpOutcome>? signUpGate;
  int signUpCalls = 0;
  String? lastEmail;
  String? lastPassword;
  User? user;

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
    lastPassword = password;
    final result = signUpGate == null ? outcome : await signUpGate!;
    if (signUpError != null) throw signUpError!;
    if (result == SignUpOutcome.session) {
      user = User(
        id: 'user-1',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        email: email,
        createdAt: '2026-01-01T00:00:00Z',
      );
    }
    return result;
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<ProfileEntity?> getProfile() async {
    final current = user;
    if (current == null) return null;
    return ProfileEntity(id: current.id);
  }

  @override
  Future<void> upsertProfile(ProfileEntity profile) async {}

  @override
  Future<ProfileEntity?> saveCheckoutPhone(String phone) async => null;

  @override
  Future<List<OrderSummaryEntity>> getOrderHistory() async => [];

  Future<void> close() => _auth.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAccountRepository repo;
  late AuthCubit cubit;

  setUp(() async {
    await sl.reset();
    repo = _FakeAccountRepository();
    cubit = AuthCubit(repo);
    sl.registerSingleton<AuthCubit>(cubit, dispose: (value) => value.close());
  });

  tearDown(() async {
    await repo.close();
    await sl.reset();
  });

  Future<void> pumpRegister(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthShellPage(initialMode: AuthShellMode.register),
      ),
    );
    await tester.pump();
  }

  Future<void> fillValid(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('register-email')),
      'buyer@tiffani.md',
    );
    await tester.enterText(
      find.byKey(const Key('register-password')),
      'secret1',
    );
    await tester.enterText(
      find.byKey(const Key('register-confirm')),
      'secret1',
    );
  }

  testWidgets('valid form submits once and passwords stay obscured', (
    tester,
  ) async {
    await pumpRegister(tester);

    final password = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('register-password')),
        matching: find.byType(TextField),
      ),
    );
    final confirm = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('register-confirm')),
        matching: find.byType(TextField),
      ),
    );
    expect(find.byKey(const Key('register-phone')), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.hintText == 'Телефон',
      ),
      findsNothing,
    );
    expect(password.obscureText, isTrue);
    expect(confirm.obscureText, isTrue);
    expect(password.autofillHints, [AutofillHints.newPassword]);

    await fillValid(tester);
    await tester.ensureVisible(find.byKey(const Key('register-submit')));
    await tester.tap(find.byKey(const Key('register-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repo.signUpCalls, 1);
    expect(repo.lastEmail, 'buyer@tiffani.md');
    expect(repo.lastPassword, 'secret1');
    expect(cubit.state.isAuthenticated, isTrue);
    expect(find.textContaining('сервер не выдал сессию'), findsNothing);
  });

  testWidgets('invalid email and password mismatch stay on the form', (
    tester,
  ) async {
    await pumpRegister(tester);
    await tester.enterText(
      find.byKey(const Key('register-email')),
      'not-an-email',
    );
    await tester.enterText(
      find.byKey(const Key('register-password')),
      'secret1',
    );
    await tester.enterText(find.byKey(const Key('register-confirm')), 'other1');
    await tester.ensureVisible(find.byKey(const Key('register-submit')));
    await tester.tap(find.byKey(const Key('register-submit')));
    await tester.pump();

    expect(find.text('Некорректный email'), findsOneWidget);
    expect(find.text('Пароли не совпадают'), findsOneWidget);
    expect(repo.signUpCalls, 0);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('register-email')))
          .controller!
          .text,
      'not-an-email',
    );
  });

  testWidgets('empty registration form shows required errors', (tester) async {
    await pumpRegister(tester);
    await tester.ensureVisible(find.byKey(const Key('register-submit')));
    await tester.tap(find.byKey(const Key('register-submit')));
    await tester.pump();

    expect(find.text('Укажите email'), findsOneWidget);
    expect(find.text('Укажите пароль'), findsOneWidget);
    expect(find.text('Подтвердите пароль'), findsNWidgets(2));
    expect(repo.signUpCalls, 0);
  });

  testWidgets('sign-up without a session explains confirmation', (
    tester,
  ) async {
    repo.outcome = SignUpOutcome.confirmationRequired;
    await pumpRegister(tester);
    await fillValid(tester);
    await tester.ensureVisible(find.byKey(const Key('register-submit')));
    await tester.tap(find.byKey(const Key('register-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(cubit.state.isAuthenticated, isFalse);
    expect(cubit.state.isLoading, isFalse);
    expect(find.textContaining('сервер не выдал сессию'), findsOneWidget);
    expect(find.text('buyer@tiffani.md'), findsOneWidget);
  });

  testWidgets('rejected email shows a specific message and keeps the input', (
    tester,
  ) async {
    repo.signUpError = AuthApiException(
      'Email address "buyer@tiffani.md" is invalid',
      statusCode: '400',
      code: 'email_address_invalid',
    );
    await pumpRegister(tester);
    await fillValid(tester);
    await tester.ensureVisible(find.byKey(const Key('register-submit')));
    await tester.tap(find.byKey(const Key('register-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text(
        'Этот email не подходит для регистрации. Укажите другой адрес.',
      ),
      findsOneWidget,
    );
    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.isAuthenticated, isFalse);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('register-email')))
          .controller!
          .text,
      'buyer@tiffani.md',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('register-password')))
          .controller!
          .text,
      'secret1',
    );
  });

  testWidgets('registration API failure shows an error and keeps the input', (
    tester,
  ) async {
    repo.signUpError = Exception('network down');
    await pumpRegister(tester);
    await fillValid(tester);
    await tester.ensureVisible(find.byKey(const Key('register-submit')));
    await tester.tap(find.byKey(const Key('register-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Произошла ошибка. Попробуйте позже.'), findsOneWidget);
    expect(cubit.state.isAuthenticated, isFalse);
    expect(cubit.state.isLoading, isFalse);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('register-email')))
          .controller!
          .text,
      'buyer@tiffani.md',
    );
  });

  testWidgets('submit stays disabled and is not sent twice while pending', (
    tester,
  ) async {
    final gate = Completer<SignUpOutcome>();
    repo.signUpGate = gate.future;
    await pumpRegister(tester);
    await fillValid(tester);
    await tester.ensureVisible(find.byKey(const Key('register-submit')));
    await tester.tap(find.byKey(const Key('register-submit')));
    await tester.pump();

    final button = tester.widget<TiffanyPrimaryButton>(
      find.byKey(const Key('register-submit')),
    );
    expect(button.onPressed, isNull);
    expect(button.isLoading, isTrue);
    await cubit.signUp(email: 'other@tiffani.md', password: 'secret1');
    expect(repo.signUpCalls, 1);
    expect(repo.lastEmail, 'buyer@tiffani.md');

    gate.complete(SignUpOutcome.session);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(cubit.state.isAuthenticated, isTrue);
  });
}
