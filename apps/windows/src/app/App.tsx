import { useEffect } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';
import { t } from '@/core/i18n';
import { useAuth } from '@/core/auth/AuthProvider';
import { AppShell } from './AppShell';
import { NAV } from './nav';
import { LoginPage } from '@/features/auth/LoginPage';
import { ComingSoon } from '@/features/placeholder/ComingSoon';

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
        {NAV.filter((n) => !n.disabled).map((n) => (
          <Route key={n.key} path={`${n.path}/*`} element={<ComingSoon menuKey={n.key} />} />
        ))}
        <Route path="*" element={<Navigate to="/overview" replace />} />
      </Route>
    </Routes>
  );
}
