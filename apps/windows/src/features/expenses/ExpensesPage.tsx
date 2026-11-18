import { useMemo, useRef, useState } from 'react';
import { Plus } from 'lucide-react';
import { t } from '@/core/i18n';
import { useAuth } from '@/core/auth/AuthProvider';
import { useQuerySnapshot } from '@/core/hooks/useSnapshot';
import { useDocSnapshot } from '@/core/hooks/useDocSnapshot';
import { newId } from '@/core/id';
import { formatDateTr } from '@/core/dates';
import { formatMinorTry, parseMinor, todayIso } from '@/core/money';
import constants from '@shared/constants.json';
import { accountFromDoc } from '@/data/finance';
import { expenseFromDoc, projectFromDoc } from '@/data/projects';
import { partyFromDoc } from '@/data/models';
import { accountsQuery, expensesQuery, partiesQuery, projectsQuery, statsRef } from '@/data/repositories';
import { cancelExpense, recordExpense } from '@/services/expenseService';
import { txErrorMessage } from '@/services/txErrors';
import { Chip, EmptyState, ErrorState, Kpi, LoadingState, Tabs } from '@/components/ui';
import { Dialog } from '@/components/Dialog';
import { useToast } from '@/components/Toast';
import { PaymentsTab } from '@/features/cashbank/CashBankPage';

type Tab = 'expenses' | 'income';
const PAGE = 50;

export function ExpensesPage() {
  const { companyId, can } = useAuth();
  const [tab, setTab] = useState<Tab>('expenses');
  const [max, setMax] = useState(PAGE);
  const [dialog, setDialog] = useState(false);
  const [cancelId, setCancelId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const toast = useToast();
  const { state } = useAuth();
  const txId = useRef(newId());
  const canWrite = can('finance.write');
  const exp = useQuerySnapshot(() => (companyId ? expensesQuery(companyId, max) : null), [companyId, max], expenseFromDoc);
  const accounts = useQuerySnapshot(() => (companyId ? accountsQuery(companyId) : null), [companyId], accountFromDoc);
  const parties = useQuerySnapshot(() => (companyId ? partiesQuery(companyId) : null), [companyId], partyFromDoc);
  const projects = useQuerySnapshot(() => (companyId ? projectsQuery(companyId) : null), [companyId], projectFromDoc);
  const stats = useDocSnapshot(companyId ? statsRef(companyId) : null, `${companyId}`, (_, x) => x);
  const month = todayIso().slice(0, 7);
  const m = (stats.data?.months as Record<string, { incomeMinor?: number; expenseMinor?: number }> | undefined)?.[month];
  const aName = useMemo(() => new Map(accounts.data.map((a) => [a.id, a.name])), [accounts.data]);
  const pName = useMemo(() => new Map(projects.data.map((p) => [p.id, p.name])), [projects.data]);

  const doCancel = async () => {
    try {
      await cancelExpense({ companyId: companyId!, uid: state.status === 'ready' ? state.user.uid : '', can }, cancelId!, txId.current);
      toast('success', t('payment.cancelledMsg')); txId.current = newId();
    } catch (e) { setError(txErrorMessage(e)); }
    setCancelId(null);
  };

  return (
    <>
      <div className="kpis" style={{ marginBottom: 'var(--s-lg)' }}>
        <Kpi title={t('dashboard.monthIncome')} value={formatMinorTry(m?.incomeMinor ?? 0)} />
        <Kpi title={t('dashboard.monthExpense')} value={formatMinorTry(m?.expenseMinor ?? 0)} />
        <Kpi title={t('expense.net')} value={formatMinorTry((m?.incomeMinor ?? 0) - (m?.expenseMinor ?? 0))} />
      </div>
      <div className="page-head">
        <Tabs<Tab> value={tab} onChange={setTab} tabs={[{ key: 'expenses', label: t('expense.expenses') }, { key: 'income', label: t('expense.collections') }]} />
        <div className="spacer" />
        {canWrite && tab === 'expenses' && <button className="btn" onClick={() => setDialog(true)}><Plus size={16} />{t('expense.new')}</button>}
      </div>
      {error && <div className="error" role="alert">{error}</div>}
      {tab === 'income' && <PaymentsTab parties={parties.data} accounts={accounts.data} canWrite={canWrite} direction="in" />}
      {tab === 'expenses' && (
        <div className="card table-wrap">
          {exp.loading ? <LoadingState /> : exp.error ? <ErrorState error={exp.error} /> : exp.data.length === 0 ? <EmptyState /> : (
            <table className="tbl"><thead><tr><th>{t('payment.date')}</th><th>{t('expense.category')}</th><th>{t('invoiceForm.description')}</th><th>{t('menu.projects')}</th><th>{t('cashBank.account')}</th>
              <th className="num">{t('payment.amount')}</th><th /></tr></thead>
              <tbody>{exp.data.map((e) => (
                <tr key={e.id}><td>{formatDateTr(e.date)}</td><td>{t(`expenseCategory.${e.categoryId}`)}</td><td>{e.description}</td><td>{e.projectId ? pName.get(e.projectId) ?? '' : ''}</td>
                  <td>{aName.get(e.accountId) ?? ''}</td><td className="num money neg">{formatMinorTry(e.amountMinor)}</td>
                  <td>{e.status === 'cancelled' ? <Chip color="var(--c-neutral)">{t('payment.cancelled')}</Chip>
                    : canWrite && <button className="btn secondary sm" onClick={() => { setError(null); setCancelId(e.id); }}>{t('payment.cancel')}</button>}</td></tr>))}</tbody></table>)}
          {exp.data.length >= max && <div style={{ textAlign: 'center', padding: 12 }}><button className="btn secondary sm" onClick={() => setMax(max + PAGE)}>{t('invoice.loadMore')}</button></div>}
        </div>)}
      {dialog && <ExpenseDialog accounts={accounts.data.filter((a) => a.active)} parties={parties.data} projects={projects.data} onClose={() => setDialog(false)} />}
      {cancelId && <Dialog title={t('payment.cancel')} onClose={() => setCancelId(null)} width={440}
        footer={<><button className="btn secondary" onClick={() => setCancelId(null)}>{t('common.cancel')}</button><button className="btn" onClick={doCancel}>{t('common.confirm')}</button></>}>{t('payment.confirmCancel')}</Dialog>}
    </>
  );
}

function ExpenseDialog({ accounts, parties, projects, onClose }: {
  accounts: { id: string; name: string }[]; parties: { id: string; name: string; active: boolean }[]; projects: { id: string; name: string }[]; onClose(): void;
}) {
  const { companyId, can, state } = useAuth();
  const toast = useToast();
  const [categoryId, setCategoryId] = useState('material');
  const [amount, setAmount] = useState('');
  const [vatBp, setVatBp] = useState(2000);
  const [accountId, setAccountId] = useState(accounts[0]?.id ?? '');
  const [partyId, setPartyId] = useState('');
  const [projectId, setProjectId] = useState('');
  const [discipline, setDiscipline] = useState('');
  const [date, setDate] = useState(todayIso());
  const [description, setDescription] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const txId = useRef(newId());

  const save = async () => {
    setBusy(true); setError(null);
    try {
      await recordExpense({ companyId: companyId!, uid: state.status === 'ready' ? state.user.uid : '', can }, {
        txId: txId.current, categoryId, amountMinor: parseMinor(amount) ?? 0, vatBp, accountId, partyId: partyId || undefined,
        projectId: projectId || undefined, discipline: projectId && discipline ? discipline : undefined, date, description,
      });
      toast('success', t('messages.paymentSaved')); onClose();
    } catch (e) { setError(txErrorMessage(e)); } finally { setBusy(false); }
  };
  return (
    <Dialog title={t('expense.new')} onClose={onClose} width={560}
      footer={<><button className="btn secondary" onClick={onClose}>{t('common.cancel')}</button><button className="btn" disabled={busy} onClick={save}>{t('common.save')}</button></>}>
      {error && <div className="error" role="alert">{error}</div>}
      <div className="grid2">
        <div className="field"><label>{t('expense.category')}</label><select value={categoryId} onChange={(e) => setCategoryId(e.target.value)}>
          {constants.defaultExpenseCategories.map((c) => <option key={c} value={c}>{t(`expenseCategory.${c}`)}</option>)}</select></div>
        <div className="field"><label>{t('cashBank.account')}</label><select value={accountId} onChange={(e) => setAccountId(e.target.value)}>
          <option value="">{t('cashBank.selectAccount')}</option>{accounts.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}</select></div>
        <div className="field"><label>{t('expense.amountGross')}</label><input value={amount} onChange={(e) => setAmount(e.target.value)} inputMode="decimal" /></div>
        <div className="field"><label>{t('invoiceForm.vat')}</label><select value={vatBp} onChange={(e) => setVatBp(Number(e.target.value))}>
          {constants.vatRatesBp.map((v) => <option key={v} value={v}>%{v / 100}</option>)}</select></div>
        <div className="field"><label>{t('payment.date')}</label><input type="date" value={date} onChange={(e) => setDate(e.target.value)} /></div>
        <div className="field"><label>{t('invoice.party')}</label><select value={partyId} onChange={(e) => setPartyId(e.target.value)}>
          <option value="" />{parties.filter((p) => p.active).map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}</select></div>
        <div className="field"><label>{t('menu.projects')}</label><select value={projectId} onChange={(e) => setProjectId(e.target.value)}>
          <option value="" />{projects.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}</select></div>
        {projectId && <div className="field"><label>{t('expense.discipline')}</label><select value={discipline} onChange={(e) => setDiscipline(e.target.value)}>
          <option value="" />{constants.disciplines.map((d) => <option key={d} value={d}>{t(`disciplines.${d}`)}</option>)}</select></div>}
      </div>
      <div className="field"><label>{t('invoiceForm.description')}</label><input value={description} onChange={(e) => setDescription(e.target.value)} /></div>
    </Dialog>
  );
}
