import 'package:supabase_flutter/supabase_flutter.dart';

import '../entities/order_summary_entity.dart';
import '../entities/profile_entity.dart';

abstract class AccountRepository {
  Stream<AuthState> get authStateChanges;
  User? get currentUser;
  bool get isAuthenticated;

  Future<void> signUp({required String email, required String password});
  Future<void> signIn({required String email, required String password});
  Future<void> signOut();

  Future<ProfileEntity?> getProfile();
  Future<void> upsertProfile(ProfileEntity profile);

  Future<List<OrderSummaryEntity>> getOrderHistory();
}
