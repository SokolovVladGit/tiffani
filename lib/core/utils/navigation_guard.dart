import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../router/product_details_payload.dart';
import '../router/route_names.dart';

/// Single-flight navigation guard for pushes onto the product details route.
///
/// The product flow is reachable from many surfaces (catalog grid, catalog
/// page, home horizontal sections, similar products, recently viewed,
/// favorites). Each surface uses a bare `context.push(...)` callback wired
/// to an `InkWell.onTap`, which means a fast double-tap, or two consecutive
/// taps on different cards within the same hero-flight window, can issue
/// two pushes back-to-back. That is the documented trigger for the Flutter
/// `HeroController` assertion `manifest.tag == newManifest.tag` in
/// `heroes.dart` (`_HeroFlight.divert`) — the controller starts a flight
/// for one hero and is asked to divert it onto a different manifest before
/// the first one finishes.
///
/// This guard provides a deliberately tiny, deterministic lock around the
/// push so the second tap is dropped instead of racing the in-flight
/// transition. It is intentionally:
///
///   * **scoped to one route** (product details) — not a generic navigation
///     framework rewrite;
///   * **time-bounded** — the lock auto-releases after a short window that
///     comfortably covers the default Material page transition, so normal
///     navigation is never blocked;
///   * **stateless from the callsite's perspective** — a single static
///     helper, no widget state, no inherited context, no DI plumbing.
class NavigationGuard {
  NavigationGuard._();

  /// True while a product-details push is in its protected window.
  static bool _busy = false;

  /// Pending unlock timer, tracked so consecutive guarded pushes do not
  /// stack overlapping timers.
  static Timer? _unlockTimer;

  /// Lock window. Sized to comfortably cover the default Material page
  /// transition (~300 ms) plus a small safety margin so the
  /// `HeroController` flight has fully settled before another push is
  /// allowed. Anything shorter risks the same divert race; anything
  /// dramatically longer would feel laggy on a real second-product tap.
  static const Duration _lockWindow = Duration(milliseconds: 600);

  /// Pushes the catalog details route at most once per [_lockWindow].
  ///
  /// Any subsequent invocation while the guard is held is a no-op — the
  /// user simply does not get a second overlapping navigation. After the
  /// window elapses the guard releases and normal navigation resumes.
  ///
  /// The push is wrapped in try/finally semantics: if `context.push` itself
  /// throws synchronously, the guard is released immediately so the UI is
  /// not left permanently locked.
  static void pushCatalogDetailsOnce(
    BuildContext context,
    ProductDetailsPayload payload,
  ) {
    if (_busy) return;
    _busy = true;

    var pushFailedSync = false;
    try {
      context.push(RouteNames.catalogDetails, extra: payload);
    } catch (_) {
      pushFailedSync = true;
      rethrow;
    } finally {
      if (pushFailedSync) {
        _unlockTimer?.cancel();
        _unlockTimer = null;
        _busy = false;
      } else {
        _unlockTimer?.cancel();
        _unlockTimer = Timer(_lockWindow, () {
          _busy = false;
          _unlockTimer = null;
        });
      }
    }
  }
}
