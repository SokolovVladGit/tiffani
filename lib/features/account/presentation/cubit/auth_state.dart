import '../../domain/entities/profile_entity.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthCubitState {
  final AuthStatus status;
  final String? email;
  final ProfileEntity? profile;
  final bool isLoading;
  final String? errorMessage;

  /// Account was created, but the server did not issue a session.
  final bool confirmationRequired;

  const AuthCubitState({
    this.status = AuthStatus.unknown,
    this.email,
    this.profile,
    this.isLoading = false,
    this.errorMessage,
    this.confirmationRequired = false,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthCubitState copyWith({
    AuthStatus? status,
    String? email,
    ProfileEntity? profile,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool clearProfile = false,
    bool? confirmationRequired,
  }) {
    return AuthCubitState(
      status: status ?? this.status,
      email: email ?? this.email,
      profile: clearProfile ? null : (profile ?? this.profile),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      confirmationRequired: confirmationRequired ?? this.confirmationRequired,
    );
  }
}
