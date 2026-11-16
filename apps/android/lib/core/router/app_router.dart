import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/no_access_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/projects/projects_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/transactions/transactions_screen.dart';
import '../auth/auth_providers.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const noAccess = '/no-access';
  static const home = '/home';
  static const transactions = '/transactions';
  static const projects = '/projects';
  static const reports = '/reports';
  static const profile = '/profile';
}

/// Riverpod durum degisimini GoRouter'a bildirir.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(userProfileProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final profile = ref.read(userProfileProvider);
      final loc = state.matchedLocation;

      if (auth.isLoading) return loc == AppRoutes.splash ? null : AppRoutes.splash;

      final user = auth.valueOrNull;
      if (user == null) return loc == AppRoutes.login ? null : AppRoutes.login;

      if (profile.isLoading) {
        return loc == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final p = profile.valueOrNull;
      final blocked = p == null || !p.active || p.companyId.isEmpty;
      if (blocked) return loc == AppRoutes.noAccess ? null : AppRoutes.noAccess;

      const gate = {AppRoutes.splash, AppRoutes.login, AppRoutes.noAccess};
      return gate.contains(loc) ? AppRoutes.home : null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.noAccess,
        builder: (_, __) => const NoAccessScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (_, __) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.transactions,
              builder: (_, __) => const TransactionsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.projects,
              builder: (_, __) => const ProjectsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.reports,
              builder: (_, __) => const ReportsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (_, __) => const ProfileScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});
