import { useCallback, useEffect, useState } from 'react';
import { Plus } from 'lucide-react';
import { t } from '@/core/i18n';
import { useAuth } from '@/core/auth/AuthProvider';
import constants from '@shared/constants.json';
import type { Permission, Role } from '@/core/types';
import { createUser, listUsers, updateUser, type UserRow } from '@/services/adminService';
import { txErrorMessage } from '@/services/txErrors';
import { Chip, EmptyState, ErrorState, LoadingState } from '@/components/ui';
import { Dialog } from '@/components/Dialog';
import { useToast } from '@/components/Toast';

export function UsersPage() {
  const { companyId, isAdmin, state } = useAuth();
  const uid = state.status === 'ready' ? state.user.uid : '';
  const [rows, setRows] = useState<UserRow[] | null>(null);
  const [error, setError] = useState<Error | null>(null);
  const [form, setForm] = useState<{ user?: UserRow } | null>(null);
  const ctx = { companyId: companyId!, uid, isAdmin };
  const load = useCallback(() => { listUsers(ctx).then(setRows).catch((e) => setError(e as Error)); }, [companyId, isAdmin]); // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => { if (isAdmin) load(); }, [isAdmin, load]);

  if (!isAdmin) return <EmptyState text={t('common.noPermission')} />;
  if (error) return <ErrorState error={error} />;
  if (!rows) return <LoadingState />;
  return (
    <div className="card">
      <div className="page-head"><h3 style={{ margin: 0 }}>{t('menu.users')}</h3><div className="spacer" /><button className="btn sm" onClick={() => setForm({})}><Plus size={14} />{t('users.new')}</button></div>
      <table className="tbl"><thead><tr><th>{t('users.name')}</th><th>{t('fields.email')}</th><th>{t('users.role')}</th><th>{t('users.permissions')}</th><th>{t('invoice.status')}</th></tr></thead>
        <tbody>{rows.map((u) => (
          <tr key={u.uid} className="row" onClick={() => setForm({ user: u })}>
            <td>{u.displayName}</td><td>{u.email}</td><td>{t(`profile.role.${u.role}`)}</td>
            <td className="sub">{u.role === 'admin' ? t('users.all') : constants.permissions.filter((p) => u.permissions[p as Permission]).map((p) => t(`users.perm.${p}`)).join(', ') || '—'}</td>
            <td>{u.active ? <Chip color="var(--c-positive)">{t('common.active')}</Chip> : <Chip color="var(--c-neutral)">{t('common.passive')}</Chip>}</td></tr>))}</tbody></table>
      {form && <UserForm ctx={ctx} user={form.user} onClose={() => setForm(null)} onSaved={load} />}
    </div>
  );
}

function UserForm({ ctx, user, onClose, onSaved }: { ctx: { companyId: string; uid: string; isAdmin: boolean }; user?: UserRow; onClose(): void; onSaved(): void }) {
  const toast = useToast();
  const [name, setName] = useState(user?.displayName ?? '');
  const [email, setEmail] = useState(user?.email ?? '');
  const [password, setPassword] = useState('');
  const [role, setRole] = useState<Role>(user?.role ?? 'employee');
  const [perms, setPerms] = useState<Partial<Record<Permission, boolean>>>(user?.permissions ?? {});
  const [active, setActive] = useState(user?.active ?? true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const save = async () => {
    setBusy(true); setError(null);
    try {
      if (!name.trim() || (!user && !email.trim())) throw new Error('required');
      if (user) await updateUser(ctx, user.uid, { displayName: name, role, permissions: perms, active });
      else await createUser(ctx, { displayName: name, email, role, permissions: perms, active }, password);
      toast('success', t('messages.saved')); onSaved(); onClose();
    } catch (e) {
      const code = (e as { code?: string }).code ?? '';
      setError(e instanceof Error && e.message === 'required' ? t('validation.required')
        : code === 'auth/email-already-in-use' ? t('users.emailInUse') : code === 'auth/invalid-email' ? t('users.invalidEmail') : txErrorMessage(e));
    } finally { setBusy(false); }
  };
  return (
    <Dialog title={user ? t('users.edit') : t('users.new')} onClose={onClose} width={520}
      footer={<><button className="btn secondary" onClick={onClose}>{t('common.cancel')}</button><button className="btn" disabled={busy} onClick={save}>{t('common.save')}</button></>}>
      {error && <div className="error" role="alert">{error}</div>}
      <div className="field"><label>{t('users.name')}</label><input value={name} onChange={(e) => setName(e.target.value)} /></div>
      <div className="field"><label>{t('fields.email')}</label><input value={email} disabled={!!user} onChange={(e) => setEmail(e.target.value)} /></div>
      {!user && <div className="field"><label>{t('auth.password')}</label><input type="password" value={password} onChange={(e) => setPassword(e.target.value)} /></div>}
      <div className="field"><label>{t('users.role')}</label><select value={role} onChange={(e) => setRole(e.target.value as Role)}>
        <option value="employee">{t('profile.role.employee')}</option><option value="admin">{t('profile.role.admin')}</option></select></div>
      {role === 'employee' && constants.permissions.map((p) => (
        <label key={p} className="check"><input type="checkbox" checked={perms[p as Permission] === true} onChange={(e) => setPerms({ ...perms, [p]: e.target.checked })} />{t(`users.perm.${p}`)}</label>))}
      <label className="check"><input type="checkbox" checked={active} onChange={(e) => setActive(e.target.checked)} />{t('fields.active')}</label>
    </Dialog>
  );
}
