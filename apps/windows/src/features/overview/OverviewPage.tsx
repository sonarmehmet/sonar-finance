import { useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { t } from '@/core/i18n';
import { useAuth } from '@/core/auth/AuthProvider';
import { useQuerySnapshot } from '@/core/hooks/useSnapshot';
import { useDocSnapshot } from '@/core/hooks/useDocSnapshot';
import { addDays, formatDateTr } from '@/core/dates';
import { formatMinorTry, todayIso } from '@/core/money';
import { invoiceFromDoc, type Invoice } from '@/data/invoice';
import { expenseFromDoc } from '@/data/projects';
import { paymentFromDoc } from '@/data/finance';
import { dueInvoicesQuery, recentExpensesQuery, recentInvoicesQuery, recentPaymentsQuery, statsRef } from '@/data/repositories';
import { ColumnChart, Sparkline } from '@/components/charts';
import { Kpi } from '@/components/ui';

interface Month { incomeMinor: number; expenseMinor: number; inMinor: number; outMinor: number }
const ZERO: Month = { incomeMinor: 0, expenseMinor: 0, inMinor: 0, outMinor: 0 };
const int = (v: unknown): number => (typeof v === 'number' && Number.isFinite(v) ? Math.trunc(v) : 0);

/** Son `n` ayın anahtarları (eski → yeni), bugünün ayı dahil. */
function lastMonths(n: number, today: string): string[] {
  let y = Number(today.slice(0, 4)), m = Number(today.slice(5, 7));
  const out: string[] = [];
  for (let i = 0; i < n; i++) { out.unshift(`${y}-${String(m).padStart(2, '0')}`); m -= 1; if (m === 0) { m = 12; y -= 1; } }
  return out;
}
/** docs/08 §2: (bu − önceki) / önceki × 100, 1 ondalık; önceki 0 ise "—". */
const change = (cur: number, prev: number): string | null => (prev === 0 ? null : `${cur >= prev ? '+' : ''}${(((cur - prev) / Math.abs(prev)) * 100).toFixed(1).replace('.', ',')}%`);

export function OverviewPage() {
  const { companyId } = useAuth();
  const navigate = useNavigate();
  const today = todayIso();
  const stats = useDocSnapshot(companyId ? statsRef(companyId) : null, `${companyId}`, (_, x) => x);
  const due = useQuerySnapshot(() => (companyId ? dueInvoicesQuery(companyId) : null), [companyId], invoiceFromDoc);
  const rInv = useQuerySnapshot(() => (companyId ? recentInvoicesQuery(companyId) : null), [companyId], invoiceFromDoc);
  const rPay = useQuerySnapshot(() => (companyId ? recentPaymentsQuery(companyId) : null), [companyId], paymentFromDoc);
  const rExp = useQuerySnapshot(() => (companyId ? recentExpensesQuery(companyId) : null), [companyId], expenseFromDoc);

  const s = stats.data ?? {};
  const monthsRaw = (s.months ?? {}) as Record<string, Partial<Month>>;
  const keys12 = useMemo(() => lastMonths(12, today), [today]);
  const m = (k: string): Month => ({ ...ZERO, ...Object.fromEntries(Object.entries(monthsRaw[k] ?? {}).map(([a, b]) => [a, int(b)])) });
  const series = keys12.map(m);
  const cur = series[11], prev = series[10];
  const cash = int(s.cashMinor), bank = int(s.bankMinor), recv = int(s.receivableMinor), pay = int(s.payableMinor);

  const limit30 = addDays(today, 30);
  const open = due.data.filter((i) => i.type === 'sales' || i.type === 'purchase');
  const collections = open.filter((i) => i.type === 'sales' && i.dueDate >= today && i.dueDate <= limit30);
  const overdueSales = open.filter((i) => i.type === 'sales' && i.dueDate < today);
  const payments = open.filter((i) => i.type === 'purchase' && i.dueDate <= limit30); // gecikmişler kırmızı satır
  const rem = (i: Invoice) => i.totalMinor - i.paidMinor;

  const recent = useMemo(() => {
    const rows = [
      ...rInv.data.filter((i) => i.status !== 'draft').map((i) => ({ k: i.id, at: i.createdAtMs, label: t(`invoiceType.${i.type}`), who: i.partyName, amount: i.totalMinor, to: `/invoices/${i.id}` })),
      ...rPay.data.map((p) => ({ k: p.id, at: 0, label: t(p.direction === 'in' ? 'payment.collection' : 'payment.payment'), who: '', amount: p.direction === 'in' ? p.amountMinor : -p.amountMinor, to: '/cash-bank', date: p.date })),
      ...rExp.data.map((e) => ({ k: e.id, at: 0, label: t('expense.expenses'), who: e.description, amount: -e.amountMinor, to: '/income-expense', date: e.date })),
    ] as { k: string; at: number; label: string; who: string; amount: number; to: string; date?: string }[];
    // payments/expenses modellerinde createdAt yok: tarih (YYYY-MM-DD) ile birleşik sırala
    const key = (r: { at: number; date?: string }) => r.date ?? new Date(r.at || 0).toISOString().slice(0, 10);
    return rows.sort((a, b) => key(b).localeCompare(key(a)) || b.at - a.at).slice(0, 10).map((r) => ({ ...r, date: key(r) }));
  }, [rInv.data, rPay.data, rExp.data]);

  const card = (title: string, value: number, vals?: number[], key?: 'incomeMinor' | 'expenseMinor') => {
    const ch = key ? change(cur[key], prev[key]) : null;
    return (
      <div className="card kpi" key={title}>
        <div className="kpi-title">{title}</div>
        <div className="kpi-value">{formatMinorTry(value)}</div>
        {vals && <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}><Sparkline values={vals.slice(-6)} color="var(--c-accent)" />{ch && <span className={ch.startsWith('+') ? 'pos' : 'neg'}>{ch}</span>}</div>}
      </div>
    );
  };

  return (
    <>
      <div className="kpis" style={{ marginBottom: 'var(--s-lg)' }}>
        {card(t('dashboard.totalCash'), cash)}{card(t('dashboard.totalBank'), bank)}
        {card(t('dashboard.totalReceivable'), recv)}{card(t('dashboard.totalPayable'), pay)}
        {card(t('dashboard.monthIncome'), cur.incomeMinor, series.map((x) => x.incomeMinor), 'incomeMinor')}
        {card(t('dashboard.monthExpense'), cur.expenseMinor, series.map((x) => x.expenseMinor), 'expenseMinor')}
      </div>
      <div className="kpis" style={{ marginBottom: 'var(--s-lg)' }}>
        <Kpi title={t('overview.netPosition')} value={formatMinorTry(cash + bank + recv - pay)} tone={cash + bank + recv - pay < 0 ? 'neg' : 'pos'} />
      </div>
      <div className="grid2" style={{ marginBottom: 'var(--s-lg)' }}>
        <div className="card"><h3 style={{ marginTop: 0 }}>{t('overview.incomeExpense')}</h3>
          <ColumnChart labels={keys12} bars={[
            { key: 'i', label: t('dashboard.monthIncome'), color: 'var(--c-positive)', values: series.map((x) => x.incomeMinor) },
            { key: 'e', label: t('dashboard.monthExpense'), color: 'var(--c-negative)', values: series.map((x) => x.expenseMinor) }]} /></div>
        <div className="card"><h3 style={{ marginTop: 0 }}>{t('overview.cashFlow')}</h3>
          <ColumnChart labels={keys12} bars={[
            { key: 'in', label: t('overview.in'), color: 'var(--c-info)', values: series.map((x) => x.inMinor) },
            { key: 'out', label: t('overview.out'), color: 'var(--c-warning)', values: series.map((x) => x.outMinor) }]}
          line={{ key: 'net', label: t('expense.net'), color: 'var(--c-accent)', values: series.map((x) => x.inMinor - x.outMinor) }} /></div>
      </div>
      <div className="grid2">
        <List title={t('dashboard.upcomingCollections')} rows={collections.map((i) => ({ k: i.id, a: i.partyName, b: formatDateTr(i.dueDate), amount: rem(i), to: `/invoices/${i.id}`, bad: false }))} />
        <List title={t('dashboard.upcoming')} rows={payments.map((i) => ({ k: i.id, a: i.partyName, b: formatDateTr(i.dueDate), amount: rem(i), to: `/invoices/${i.id}`, bad: i.dueDate < today }))} />
        <List title={t('dashboard.overdue')} rows={overdueSales.map((i) => ({ k: i.id, a: i.partyName, b: formatDateTr(i.dueDate), amount: rem(i), to: `/invoices/${i.id}`, bad: true }))} />
        <List title={t('dashboard.recent')} rows={recent.map((r) => ({ k: r.k, a: `${r.label}${r.who ? ` · ${r.who}` : ''}`, b: formatDateTr(r.date!), amount: r.amount, to: r.to, bad: false }))} signed />
      </div>
    </>
  );

  function List({ title, rows, signed }: { title: string; rows: { k: string; a: string; b: string; amount: number; to: string; bad: boolean }[]; signed?: boolean }) {
    return (
      <div className="card" style={{ marginBottom: 'var(--s-lg)' }}>
        <h3 style={{ marginTop: 0 }}>{title}</h3>
        {rows.length === 0 ? <div className="sub">{t('common.empty')}</div> : rows.map((r) => (
          <div key={r.k} className="list-item" onClick={() => navigate(r.to)} style={{ padding: '8px 0' }}>
            <div className="grow"><div className={`name ${r.bad ? 'neg' : ''}`}>{r.a}</div><div className="sub">{r.b}</div></div>
            <span className={`money ${signed ? (r.amount >= 0 ? 'pos' : 'neg') : r.bad ? 'neg' : ''}`}>{formatMinorTry(r.amount)}</span>
          </div>))}
      </div>
    );
  }
}
