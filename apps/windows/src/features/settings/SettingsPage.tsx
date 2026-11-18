import { useEffect, useState } from 'react';
import { waitForPendingWrites, type DocumentData } from 'firebase/firestore';
import { t } from '@/core/i18n';
import { useAuth } from '@/core/auth/AuthProvider';
import { useQuerySnapshot } from '@/core/hooks/useSnapshot';
import { useConnectionState } from '@/core/connection';
import { db } from '@/core/firebase';
import { formatMinorTry } from '@/core/money';
import constants from '@shared/constants.json';
import { invoicesQuery, partiesQuery, productsQuery } from '@/data/repositories';
import { backupHistory, checkConsistency, exportBackup, saveSettings, type Diff, type SettingsInput } from '@/services/adminService';
import { txErrorMessage } from '@/services/txErrors';
import { Tabs } from '@/components/ui';
import { useToast } from '@/components/Toast';

type Tab = 'company' | 'sync' | 'backup' | 'check';

export function SettingsPage() {
  const { isAdmin } = useAuth();
  const [tab, setTab] = useState<Tab>('company');
  return (
    <>
      <Tabs<Tab> value={tab} onChange={setTab} tabs={[
        { key: 'company', label: t('settings.company') }, { key: 'sync', label: t('settings.sync') },
        ...(isAdmin ? [{ key: 'backup' as Tab, label: t('settings.backup') }, { key: 'check' as Tab, label: t('settings.check') }] : [])]} />
      {tab === 'company' && <CompanyTab />}
      {tab === 'sync' && <SyncTab />}
      {tab === 'backup' && isAdmin && <BackupTab />}
      {tab === 'check' && isAdmin && <CheckTab />}
    </>
  );
}

function useAdminCtx() {
  const { companyId, isAdmin, state } = useAuth();
  return { companyId: companyId!, uid: state.status === 'ready' ? state.user.uid : '', isAdmin };
}

function CompanyTab() {
  const { state, isAdmin } = useAuth();
  const ctx = useAdminCtx();
  const toast = useToast();
  const c = state.status === 'ready' ? state.company : null;
  const raw = c as unknown as { taxNo?: string; taxOffice?: string; address?: string; phone?: string } | null;
  const [f, setF] = useState<SettingsInput>(() => ({
    name: c?.name ?? '', taxNo: raw?.taxNo ?? '', taxOffice: raw?.taxOffice ?? '', address: raw?.address ?? '', phone: raw?.phone ?? '',
    allowNegativeStock: c?.settings.allowNegativeStock ?? false, defaultVatBp: c?.settings.defaultVatBp ?? 2000,
    prefixes: { sales: c?.settings.invoicePrefix?.sales ?? 'SF', purchase: c?.settings.invoicePrefix?.purchase ?? 'AF', sales_return: c?.settings.invoicePrefix?.sales_return ?? 'SI', purchase_return: c?.settings.invoicePrefix?.purchase_return ?? 'AI' },
  }));
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const set = <K extends keyof SettingsInput>(k: K, v: SettingsInput[K]) => setF((x) => ({ ...x, [k]: v }));
  const save = async () => {
    setBusy(true); setError(null);
    try { await saveSettings(ctx, f); toast('success', t('messages.saved')); } catch (e) { setError(txErrorMessage(e)); } finally { setBusy(false); }
  };
  const ro = !isAdmin;
  return (
    <div className="card" style={{ maxWidth: 760 }}>
      {error && <div className="error" role="alert">{error}</div>}
      <div className="grid2">
        <div className="field"><label>{t('settings.companyName')}</label><input disabled={ro} value={f.name} onChange={(e) => set('name', e.target.value)} /></div>
        <div className="field"><label>{t('fields.taxNo')}</label><input disabled={ro} value={f.taxNo} onChange={(e) => set('taxNo', e.target.value)} /></div>
        <div className="field"><label>{t('fields.taxOffice')}</label><input disabled={ro} value={f.taxOffice} onChange={(e) => set('taxOffice', e.target.value)} /></div>
        <div className="field"><label>{t('party.phone')}</label><input disabled={ro} value={f.phone} onChange={(e) => set('phone', e.target.value)} /></div>
      </div>
      <div className="field"><label>{t('fields.address')}</label><input disabled={ro} value={f.address} onChange={(e) => set('address', e.target.value)} /></div>
      <h4>{t('settings.invoicing')}</h4>
      <div className="grid2">
        <div className="field"><label>{t('fields.vat')}</label><select disabled={ro} value={f.defaultVatBp} onChange={(e) => set('defaultVatBp', Number(e.target.value))}>
          {constants.vatRatesBp.map((v) => <option key={v} value={v}>%{v / 100}</option>)}</select></div>
        <div />
        {(['sales', 'purchase', 'sales_return', 'purchase_return'] as const).map((k) => (
          <div className="field" key={k}><label>{t(`invoiceType.${k}`)} — {t('settings.prefix')}</label>
            <input disabled={ro} value={f.prefixes[k]} maxLength={6} onChange={(e) => set('prefixes', { ...f.prefixes, [k]: e.target.value.toUpperCase() })} /></div>))}
      </div>
      <label className="check"><input type="checkbox" disabled={ro} checked={f.allowNegativeStock} onChange={(e) => set('allowNegativeStock', e.target.checked)} />{t('settings.allowNegative')}</label>
      {isAdmin && <button className="btn" disabled={busy} onClick={save}>{t('common.save')}</button>}
    </div>
  );
}

/** docs/05: bekleyen (sunucuya gitmemiş) yazmalar. Hiçbir bekleyen veri sessizce silinmez. */
function SyncTab() {
  const { companyId } = useAuth();
  const toast = useToast();
  const conn = useConnectionState();
  const inv = useQuerySnapshot(() => (companyId ? invoicesQuery(companyId, 'all', 100) : null), [companyId], (d) => ({ id: d.id, label: `${t('menu.invoices')} · ${String(d.data().number ?? d.data().partyName ?? d.id)}`, pending: d.metadata.hasPendingWrites }));
  const par = useQuerySnapshot(() => (companyId ? partiesQuery(companyId) : null), [companyId], (d) => ({ id: d.id, label: `${t('menu.parties')} · ${String((d.data() as DocumentData).name ?? d.id)}`, pending: d.metadata.hasPendingWrites }));
  const pro = useQuerySnapshot(() => (companyId ? productsQuery(companyId) : null), [companyId], (d) => ({ id: d.id, label: `${t('stock.products')} · ${String((d.data() as DocumentData).name ?? d.id)}`, pending: d.metadata.hasPendingWrites }));
  const pending = [...inv.data, ...par.data, ...pro.data].filter((x) => x.pending);
  const [busy, setBusy] = useState(false);
  const retry = async () => {
    setBusy(true);
    try { await Promise.race([waitForPendingWrites(db), new Promise((_, rej) => setTimeout(() => rej(new Error('timeout')), 15000))]); toast('success', t('settings.syncDone')); } catch { toast('error', t('settings.syncStill')); } finally { setBusy(false); }
  };
  return (
    <div className="card" style={{ maxWidth: 760 }}>
      <p><span className={`dot ${conn}`} /> {t(`connection.${conn}`)}</p>
      {pending.length === 0 ? <div className="sub">{t('settings.noPending')}</div> : (
        <table className="tbl"><tbody>{pending.map((p) => <tr key={p.id}><td>{p.label}</td><td><span className="chip" style={{ color: 'var(--c-warning)' }}>{t('settings.waiting')}</span></td></tr>)}</tbody></table>)}
      <div style={{ marginTop: 12 }}><button className="btn secondary" disabled={busy || pending.length === 0} onClick={retry}>{t('common.retry')}</button></div>
    </div>
  );
}

function BackupTab() {
  const ctx = useAdminCtx();
  const toast = useToast();
  const [busy, setBusy] = useState(false);
  const [step, setStep] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [hist, setHist] = useState<string[]>(backupHistory());
  const run = async () => {
    setBusy(true); setError(null);
    try { const r = await exportBackup(ctx, setStep); toast('success', `${r.filename} (${r.docs})`); setHist(backupHistory()); } catch (e) { setError(txErrorMessage(e)); } finally { setBusy(false); setStep(''); }
  };
  return (
    <div className="card" style={{ maxWidth: 760 }}>
      <p>{t('settings.backupHelp')}</p>
      {error && <div className="error" role="alert">{error}</div>}
      <button className="btn" disabled={busy} onClick={run}>{busy ? `${t('common.loading')} ${step}` : t('settings.backupNow')}</button>
      <h4>{t('settings.backupHistory')}</h4>
      {hist.length === 0 ? <div className="sub">{t('common.empty')}</div> : hist.map((h) => <div key={h} className="sub">{h}</div>)}
      <p className="sub" style={{ marginTop: 16 }}>{t('settings.restoreHelp')}</p>
    </div>
  );
}

function CheckTab() {
  const ctx = useAdminCtx();
  const [diffs, setDiffs] = useState<Diff[] | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  useEffect(() => { setDiffs(null); }, []);
  const run = async () => { setBusy(true); setError(null); try { setDiffs(await checkConsistency(ctx)); } catch (e) { setError(txErrorMessage(e)); } finally { setBusy(false); } };
  const fmt = (d: Diff, n: number) => (d.kind === 'stockLevel' || d.kind === 'productTotal' ? String(n / 1000) : formatMinorTry(n));
  return (
    <div className="card" style={{ maxWidth: 860 }}>
      <p>{t('settings.checkHelp')}</p>
      {error && <div className="error" role="alert">{error}</div>}
      <button className="btn" disabled={busy} onClick={run}>{busy ? t('common.loading') : t('settings.checkRun')}</button>
      {diffs && (diffs.length === 0 ? <p className="pos">{t('settings.checkOk')}</p> : (
        <table className="tbl" style={{ marginTop: 12 }}><thead><tr><th>{t('settings.checkKind')}</th><th>{t('stock.name')}</th><th className="num">{t('settings.stored')}</th><th className="num">{t('settings.computed')}</th></tr></thead>
          <tbody>{diffs.map((d) => <tr key={`${d.kind}${d.id}`}><td>{t(`settings.kind.${d.kind}`)}</td><td>{d.label}</td><td className="num">{fmt(d, d.stored)}</td><td className="num neg">{fmt(d, d.computed)}</td></tr>)}</tbody></table>))}
      {diffs && diffs.length > 0 && <p className="sub">{t('settings.fixHelp')}</p>}
    </div>
  );
}
