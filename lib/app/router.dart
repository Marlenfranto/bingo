import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models/user_model.dart';
import '../features/auth/auth_providers.dart';
import '../features/bingo/dashboard_screen.dart';
import '../features/network/connections_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/qr/qr_generator_screen.dart';
import '../features/qr/qr_scanner_screen.dart';
import '../features/scoreboard/scoreboard_screen.dart';
import '../features/shell/shell_screen.dart';
import '../features/splash/splash_screen.dart';

/// Bridges Riverpod auth/user state into a [Listenable] that GoRouter can
/// observe via `refreshListenable`. Keeps the redirect logic side-effect free.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _ref.listen<AsyncValue<User?>>(authStateProvider, (_, __) => notifyListeners());
    _ref.listen<AsyncValue<UserModel?>>(currentUserProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  // Kick off anonymous sign-in once the router is built.
  ref.read(authBootstrapProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final user = ref.read(currentUserProvider);
      final path = state.uri.path;

      // Scoreboard is a kiosk view — always let it through. It handles its
      // own loading state inside the widget so a freshly-opened kiosk URL
      // doesn't get bounced through /splash → /onboarding while auth resolves.
      if (path == '/scoreboard') return null;

      // Standard auth gate for everything else.
      if (auth.isLoading) return path == '/splash' ? null : '/splash';
      if (auth.valueOrNull == null) {
        return path == '/splash' ? null : '/splash';
      }
      if (user.isLoading) return path == '/splash' ? null : '/splash';
      if (user.valueOrNull == null) {
        return path == '/onboarding' ? null : '/onboarding';
      }
      if (path == '/splash' || path == '/onboarding') return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (_, __) => _fadeSlidePage(const OnboardingScreen()),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (_, __) => _modalSlidePage(const ProfileScreen()),
      ),
      GoRoute(
        path: '/scan',
        pageBuilder: (_, state) => _modalSlidePage(
          QrScannerScreen(args: state.extra as Map<String, dynamic>?),
        ),
      ),
      GoRoute(
        path: '/scoreboard',
        builder: (_, __) => const ScoreboardScreen(),
      ),
      ShellRoute(
        builder: (_, __, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (_, __) => _shellFadePage(const DashboardScreen()),
          ),
          GoRoute(
            path: '/connections',
            pageBuilder: (_, __) => _shellFadePage(const ConnectionsScreen()),
          ),
          GoRoute(
            path: '/qr-code',
            pageBuilder: (_, __) => _shellFadePage(const QrGeneratorScreen()),
          ),
        ],
      ),
    ],
  );
});

/// Fade + small upward slide. Default transition for screens that push on
/// top of the current stack (onboarding etc).
CustomTransitionPage<void> _fadeSlidePage(Widget child) {
  return CustomTransitionPage<void>(
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (_, animation, __, c) {
      final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
              .animate(curve),
          child: c,
        ),
      );
    },
  );
}

/// Bottom-sheet-feel slide. For modal-ish screens (profile, scanner).
CustomTransitionPage<void> _modalSlidePage(Widget child) {
  return CustomTransitionPage<void>(
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (_, animation, __, c) {
      final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.10), end: Offset.zero)
            .animate(curve),
        child: FadeTransition(opacity: curve, child: c),
      );
    },
  );
}

/// Quick cross-fade for tab swaps inside the bottom-nav shell. Shorter than
/// the modal transitions so it doesn't feel laggy when bouncing between tabs.
CustomTransitionPage<void> _shellFadePage(Widget child) {
  return CustomTransitionPage<void>(
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (_, animation, __, c) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: c,
    ),
  );
}
