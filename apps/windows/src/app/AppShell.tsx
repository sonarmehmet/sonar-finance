import { useState } from 'react';
import { NavLink, Outlet, useLocation } from 'react-router-dom';
import { Bell, LogOut, PanelLeftClose, PanelLeftOpen, Plus, Search } from 'lucide-react';
import { t } from '@/core/i18n';
import { useAuth } from '@/core/auth/AuthProvider';
import { useConnectionState } from '@/core/connection';
import { NAV } from './nav';

export function AppShell() {
  const [collapsed, setCollapsed] = useState(false);
  const { state, signOut } = useAuth();
  const conn = useConnectionState();
  const loc = useLocation();
  const current = NAV.find((n) => loc.pathname.startsWith(n.path));
  const title = current ? t(`menu.${current.key}`) : t('app.name');
  const name = state.status === 'ready' ? state.profile.displayName : '';

  return (
    <div className={`shell ${collapsed ? 'collapsed' : ''}`}>
      <aside className="sidebar">
        <div className="brand">
          <img src="/app-icon.png" alt="" />
          <span>{t('app.name')}</span>
        </div>
        <nav className="nav">
          {NAV.map((n) => {
            const Icon = n.icon;
            const label = t(`menu.${n.key}`);
            return (
              <div key={n.key}>
                {n.sepBefore && <div className="nav-sep" />}
                {n.disabled ? (
                  <div className="disabled" title={label}><Icon size={20} /><span className="label">{label}</span></div>
                ) : (
                  <NavLink to={n.path} className={({ isActive }) => (isActive ? 'active' : '')} title={label}>
                    <Icon size={20} strokeWidth={1.75} /><span className="label">{label}</span>
                  </NavLink>
                )}
              </div>
            );
          })}
        </nav>
        <button className="icon-btn" style={{ margin: 8 }} onClick={() => setCollapsed((c) => !c)} aria-label="Menüyü daralt/genişlet">
          {collapsed ? <PanelLeftOpen size={20} /> : <PanelLeftClose size={20} />}
        </button>
      </aside>

      <div className="main">
        <header className="topbar">
          <div>
            <h1>{title}</h1>
            <div className="crumb">{t('app.name')} / {title}</div>
          </div>
          <div className="spacer" />
          <label className="search"><Search size={16} /><input placeholder={t('common.search')} /></label>
          <span className="badge" title={t(`connection.${conn}`)}><span className={`dot ${conn}`} />{t(`connection.${conn}`)}</span>
          <button className="btn"><Plus size={16} />{t('invoiceForm.newInvoice')}</button>
          <button className="icon-btn" aria-label="Bildirimler"><Bell size={20} /></button>
          <span className="crumb">{name}</span>
          <button className="icon-btn" onClick={() => void signOut()} aria-label={t('auth.signOut')} title={t('auth.signOut')}><LogOut size={20} /></button>
        </header>
        <main className="content"><Outlet /></main>
      </div>
    </div>
  );
}
