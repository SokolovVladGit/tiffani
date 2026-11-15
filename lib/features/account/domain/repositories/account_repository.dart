import 'package:supabase_flutter/supabase_flutter.dart';

import '../entities/order_summary_entity.dart';
import '../entities/profile_entity.dart';
import '../sign_up_outcome.dart';

abstract class AccountRepository {
  Stream<AuthState> get authStateChanges;
  User? get currentUser;
  bool get isAuthenticated;

  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  });
  Future<void> signIn({required String email, required String password});
  Future<void> signOut();

  Future<ProfileEntity?> getProfile();
  Future<void> upsertProfile(ProfileEntity profile);

  /// Stores the phone from a successful checkout on the signed-in profile.
  /// Returns null for a guest. Does not write when the number is unchanged.
  Future<ProfileEntity?> saveCheckoutPhone(String phone);

  Future<List<OrderSummaryEntity>> getOrderHistory();
}
