import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/accounts/account_detail_screen.dart';
import '../../features/accounts/accounts_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/expenses/expense_form_screen.dart';
import '../../features/expenses/expenses_list_screen.dart';
import '../../features/projects/project_detail_screen.dart';
import '../../features/reports/report_screen.dart';
import '../../features/projects/project_form_screen.dart';
import '../../features/invoices/invoices_list_screen.dart';
import '../../features/payments/payment_detail_screen.dart';
import '../../features/payments/payment_form_screen.dart';
import '../../features/payments/payments_list_screen.dart';
import '../../features/auth/no_access_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/invoices/invoice_detail_screen.dart';
import '../../features/invoices/invoice_form_screen.dart';
import '../../features/parties/parties_list_screen.dart';
import '../../features/parties/party_detail_screen.dart';
import '../../features/parties/party_form_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/stock/product_detail_screen.dart';
import '../../features/stock/product_form_screen.dart';
import '../../features/stock/products_list_screen.dart';
import '../../features/stock/warehouses_screen.dart';
import '../../features/projects/projects_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/transactions/transactions_screen.dart';
import '../auth/auth_providers.dart';
import '../providers.dart';

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
      // Tam ekran (alt menusuz) ekranlar. Statik yollar (`new`) parametreli yoldan once.
      GoRoute(
        path: '/parties',
        builder: (_, __) => const PartiesListScreen(),
        routes: [
          GoRoute(path: 'new', builder: (_, __) => const PartyFormScreen()),
          GoRoute(
            path: ':id',
            builder: (_, st) =>
                PartyDetailScreen(partyId: st.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, st) =>
                    PartyFormScreen(partyId: st.pathParameters['id']),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/products',
        builder: (_, __) => const ProductsListScreen(),
        routes: [
          GoRoute(path: 'new', builder: (_, __) => const ProductFormScreen()),
          GoRoute(
            path: ':id',
            builder: (_, st) =>
                ProductDetailScreen(productId: st.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, st) =>
                    ProductFormScreen(productId: st.pathParameters['id']),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/invoices',
        // Ust rotaya `redirect` konmaz: alt rotalari (new, :id) da yonlendirirdi.
        builder: (ctx, __) => InvoicesListScreen(title: ProviderScope.containerOf(ctx).read(stringsProvider)('mobileNav.transactions')),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, st) =>
                InvoiceFormScreen(type: st.uri.queryParameters['type']),
          ),
          GoRoute(
            path: ':id',
            builder: (_, st) =>
                InvoiceDetailScreen(invoiceId: st.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, st) =>
                    InvoiceFormScreen(invoiceId: st.pathParameters['id']),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/expenses',
        builder: (_, st) => ExpensesListScreen(projectId: st.uri.queryParameters['projectId']),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, st) => ExpenseFormScreen(projectId: st.uri.queryParameters['projectId']),
          ),
        ],
      ),
      GoRoute(
        path: '/reports/:kind',
        builder: (_, st) => ReportScreen(kind: st.pathParameters['kind']!),
      ),
      GoRoute(
        path: '/accounts',
        builder: (_, __) => const AccountsScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, st) => AccountDetailScreen(accountId: st.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/payments',
        builder: (_, __) => const PaymentsListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, st) => PaymentFormScreen(
              direction: st.uri.queryParameters['direction'] ?? 'in',
              partyId: st.uri.queryParameters['partyId'],
            ),
          ),
          GoRoute(
            path: ':id',
            builder: (_, st) => PaymentDetailScreen(paymentId: st.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/warehouses',
        builder: (_, __) => const WarehousesScreen(),
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
            routes: [
              GoRoute(path: 'new', builder: (_, __) => const ProjectFormScreen()),
              GoRoute(
                path: ':id',
                builder: (_, st) => ProjectDetailScreen(projectId: st.pathParameters['id']!),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (_, st) => ProjectFormScreen(projectId: st.pathParameters['id']),
                  ),
                ],
              ),
            ],
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
