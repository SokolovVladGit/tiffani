import 'package:flutter/material.dart';

import '../core/di/injector.dart';
import '../features/cart/presentation/cubit/cart_cubit.dart';
import 'app.dart';

/// Initializes all dependencies and runs the application.
Future<void> bootstrap() async {
  try {
    await setupDependencies();
    await sl<CartCubit>().loadCart();
    runApp(const App());
  } catch (e, st) {
    debugPrint('Bootstrap failed: $e\n$st');
    rethrow;
  }
}
