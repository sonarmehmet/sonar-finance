import { useEffect } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';
import { t } from '@/core/i18n';
import { useAuth } from '@/core/auth/AuthProvider';
import { AppShell } from './AppShell';
import { NAV } from './nav';
import { LoginPage } from '@/features/auth/LoginPage';
import { ComingSoon } from '@/features/placeholder/ComingSoon';
import { PartiesPage } from '@/features/parties/PartiesPage';
import { InvoicesPage } from '@/features/invoices/InvoicesPage';
import { InvoiceFormPage } from '@/features/invoices/InvoiceFormPage';
import { InvoiceDetailPage } from '@/features/invoices/InvoiceDetailPage';
import { CashBankPage } from '@/features/cashbank/CashBankPage';
import { ExpensesPage } from '@/features/expenses/ExpensesPage';
import { ProjectsPage } from '@/features/projects/ProjectsPage';
import { OverviewPage } from '@/features/overview/OverviewPage';
import { ReportsPage } from '@/features/reports/ReportsPage';
import { StockPage } from '@/features/stock/StockPage';

export function App() {
  const { state, signOut } = useAuth();

  const errorCode = state.status === 'error' ? state.code : null;
  useEffect(() => {
    // Profil yok / pasif: oturumu kapat, nedeni giriş ekranında göster.
    if (errorCode) void signOut();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [errorCode]);

  if (state.status === 'loading') return <div className="center-screen">{t('common.loading')}</div>;
  if (state.status === 'signedOut') return <LoginPage />;
  if (state.status === 'error') return <LoginPage initialError={t(`auth.errors.${state.code}`)} />;

  return (
    <Routes>
      <Route element={<AppShell />}>
        <Route index element={<Navigate to="/overview" replace />} />
        <Route path="/parties/:id?" element={<PartiesPage />} />
        <Route path="/invoices" element={<InvoicesPage />} />
        <Route path="/invoices/new" element={<InvoiceFormPage />} />
        <Route path="/invoices/:id/edit" element={<InvoiceFormPage />} />
        <Route path="/invoices/:id" element={<InvoiceDetailPage />} />
        <Route path="/cash-bank" element={<CashBankPage />} />
        <Route path="/income-expense" element={<ExpensesPage />} />
        <Route path="/projects/:id?" element={<ProjectsPage />} />
        <Route path="/overview" element={<OverviewPage />} />
        <Route path="/reports" element={<ReportsPage />} />
        <Route path="/stock/*" element={<StockPage />} />
        {NAV.filter((n) => !n.disabled && n.key !== 'parties' && n.key !== 'stock' && n.key !== 'invoices' && n.key !== 'cashBank' && n.key !== 'incomeExpense' && n.key !== 'overview' && n.key !== 'reports' && n.key !== 'projects').map((n) => (
          <Route key={n.key} path={`${n.path}/*`} element={<ComingSoon menuKey={n.key} />} />
        ))}
        <Route path="*" element={<Navigate to="/overview" replace />} />
      </Route>
    </Routes>
  );
}
