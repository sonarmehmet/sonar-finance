import { useState } from 'react';
import { FileSpreadsheet, Printer } from 'lucide-react';
import { t } from '@/core/i18n';
import { useAuth } from '@/core/auth/AuthProvider';
import { addDays } from '@/core/dates';
import { formatMinorTry, todayIso } from '@/core/money';
import { txErrorMessage } from '@/services/txErrors';
import { EmptyState, LoadingState } from '@/components/ui';
import { build, NEEDS_RANGE, REPORT_KEYS, type Opts, type ReportKey } from './builders';
import { exportXlsx, printReport, type ReportData } from './export';

export function ReportsPage() {
  const { companyId, state } = useAuth();
  const today = todayIso();
  const [key, setKey] = useState<ReportKey>('monthly');
  const [o, setO] = useState<Opts>({ from: addDays(today, -30), to: today, month: today.slice(0, 7), year: today.slice(0, 4), includeCancelled: false });
  const [data, setData] = useState<ReportData | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const company = state.status === 'ready' ? state.company.name : '';

  const run = async () => {
    setLoading(true); setError(null);
    try { setData(await build(key, companyId!, o)); } catch (e) { setData(null); setError(txErrorMessage(e)); } finally { setLoading(false); }
  };
  const cell = (v: unknown, money?: boolean) => (money && typeof v === 'number' ? formatMinorTry(v) : String(v ?? ''));

  return (
    <div>
      <div className="no-print">
        <div className="filters" style={{ border: 0, padding: 0, marginBottom: 'var(--s-lg)' }}>
          {REPORT_KEYS.map((k) => <button key={k} className={`pill ${k === key ? 'on' : ''}`} onClick={() => { setKey(k); setData(null); }}>{t(`reports.${k}`)}</button>)}
        </div>
        <div className="card" style={{ display: 'flex', gap: 'var(--s-lg)', alignItems: 'flex-end', flexWrap: 'wrap', marginBottom: 'var(--s-lg)' }}>
          {NEEDS_RANGE.includes(key) && <>
            <div className="field" style={{ margin: 0 }}><label>{t('reports.from')}</label><input type="date" value={o.from} onChange={(e) => setO({ ...o, from: e.target.value })} /></div>
            <div className="field" style={{ margin: 0 }}><label>{t('reports.to')}</label><input type="date" value={o.to} onChange={(e) => setO({ ...o, to: e.target.value })} /></div>
            <label className="check" style={{ margin: 0 }}><input type="checkbox" checked={o.includeCancelled} onChange={(e) => setO({ ...o, includeCancelled: e.target.checked })} />{t('reports.includeCancelled')}</label></>}
          {key === 'monthly' && <div className="field" style={{ margin: 0 }}><label>{t('reports.month')}</label><input type="month" value={o.month} onChange={(e) => setO({ ...o, month: e.target.value })} /></div>}
          {key === 'yearly' && <div className="field" style={{ margin: 0 }}><label>{t('reports.year')}</label><input value={o.year} maxLength={4} style={{ width: 90 }} onChange={(e) => setO({ ...o, year: e.target.value })} /></div>}
          <button className="btn" disabled={loading} onClick={run}>{t('reports.run')}</button>
          <div className="spacer" />
          <button className="btn secondary" disabled={!data} onClick={() => data && exportXlsx(data, company, `${t(`reports.${key}`)}-${today}`)}><FileSpreadsheet size={16} />{t('reports.excel')}</button>
          <button className="btn secondary" disabled={!data} onClick={printReport}><Printer size={16} />{t('reports.pdf')}</button>
        </div>
      </div>
      {error && <div className="error" role="alert">{error}</div>}
      {loading ? <LoadingState /> : !data ? <EmptyState text={t('reports.title')} /> : (
        <div className="card">
          <div className="print-only" style={{ marginBottom: 12 }}><strong>{company}</strong></div>
          <h2 style={{ margin: 0 }}>{data.title}</h2>
          <div className="sub" style={{ marginBottom: 8 }}>{data.range} · {t('reports.generated')}: {new Date().toLocaleString('tr-TR')}</div>
          <div className="kpis" style={{ marginBottom: 'var(--s-lg)' }}>
            {data.summary.map(([k, v, money]) => <div key={k} className="card kpi"><div className="kpi-title">{k}</div><div className="kpi-value">{cell(v, money)}</div></div>)}
          </div>
          {data.rows.length === 0 ? <EmptyState /> : (
            <div className="table-wrap"><table className="tbl">
              <thead><tr>{data.columns.map((c) => <th key={c.key} className={c.money || c.num ? 'num' : ''}>{c.label}</th>)}</tr></thead>
              <tbody>{data.rows.map((r, i) => <tr key={i}>{data.columns.map((c) => <td key={c.key} className={c.money || c.num ? 'num money' : ''}>{cell(r[c.key], c.money)}</td>)}</tr>)}</tbody>
            </table></div>)}
        </div>)}
    </div>
  );
}
