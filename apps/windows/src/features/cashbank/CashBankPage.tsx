import { useMemo, useRef, useState } from 'react';
import { ArrowLeftRight, Pencil, Plus } from 'lucide-react';
import { t } from '@/core/i18n';
import { useAuth } from '@/core/auth/AuthProvider';
import { useQuerySnapshot } from '@/core/hooks/useSnapshot';
import { newId } from '@/core/id';
import { formatDateTr } from '@/core/dates';
import { formatMinorTry } from '@/core/money';
import { accountFromDoc, accountMovementFromDoc, paymentFromDoc, type Account, type Payment, type PaymentDirection } from '@/data/finance';
import { partyFromDoc } from '@/data/models';
import { accountMovementsQuery, accountsQuery, partiesQuery, paymentsQuery } from '@/data/repositories';
import { cancelPayment } from '@/services/paymentService';
import { txErrorMessage } from '@/services/txErrors';
import { Balance, Chip, EmptyState, ErrorState, Kpi, LoadingState, Tabs } from '@/components/ui';
import { Dialog } from '@/components/Dialog';
import { useToast } from '@/components/Toast';
import { PaymentDialog } from './PaymentDialog';
import { AccountForm, TransferDialog } from './AccountDialogs';

type Tab = 'accounts' | 'payments';

export function CashBankPage() {
  const { companyId, can } = useAuth();
  const [tab, setTab] = useState<Tab>('accounts');
  const accounts = useQuerySnapshot(() => (companyId ? accountsQuery(companyId) : null), [companyId], accountFromDoc);
  const parties = useQuerySnapshot(() => (companyId ? partiesQuery(companyId) : null), [companyId], partyFromDoc);
  const [pay, setPay] = useState<PaymentDirection | null>(null);
  const [transfer, setTransfer] = useState(false);
  const [form, setForm] = useState<{ account?: Account; type: 'cash' | 'bank' } | null>(null);
  const canWrite = can('finance.write');
  const cash = accounts.data.filter((a) => a.active && a.type === 'cash').reduce((s, a) => s + a.balanceMinor, 0);
  const bank = accounts.data.filter((a) => a.active && a.type === 'bank').reduce((s, a) => s + a.balanceMinor, 0);

  return (
    <>
      <div className="kpis" style={{ marginBottom: 'var(--s-lg)' }}>
        <Kpi title={t('cashBank.totalCash')} value={formatMinorTry(cash)} />
        <Kpi title={t('cashBank.totalBank')} value={formatMinorTry(bank)} />
      </div>
      <div className="page-head">
        <Tabs<Tab> value={tab} onChange={setTab} tabs={[{ key: 'accounts', label: t('cashBank.accounts') }, { key: 'payments', label: t('cashBank.payments') }]} />
        <div className="spacer" />
        {canWrite && <>
          <button className="btn sm" onClick={() => setPay('in')}>{t('cashBank.income')}</button>
          <button className="btn secondary sm" onClick={() => setPay('out')}>{t('cashBank.outcome')}</button>
          <button className="btn secondary sm" onClick={() => setTransfer(true)}><ArrowLeftRight size={14} />{t('cashBank.transfer')}</button>
          <button className="btn secondary sm" onClick={() => setForm({ type: 'cash' })}><Plus size={14} />{t('cashBank.newCash')}</button>
          <button className="btn secondary sm" onClick={() => setForm({ type: 'bank' })}><Plus size={14} />{t('cashBank.newBank')}</button></>}
      </div>
      {tab === 'accounts' && <AccountsTab accounts={accounts.data} loading={accounts.loading} error={accounts.error} canWrite={canWrite} onEdit={(a) => setForm({ account: a, type: a.type })} />}
      {tab === 'payments' && <PaymentsTab parties={parties.data} accounts={accounts.data} canWrite={canWrite} />}
      {pay && <PaymentDialog direction={pay} parties={parties.data} accounts={accounts.data} onClose={() => setPay(null)} />}
      {transfer && <TransferDialog accounts={accounts.data} onClose={() => setTransfer(false)} />}
      {form && <AccountForm account={form.account} type={form.type} onClose={() => setForm(null)} />}
    </>
  );
}

function AccountsTab({ accounts, loading, error, canWrite, onEdit }: { accounts: Account[]; loading: boolean; error: Error | null; canWrite: boolean; onEdit(a: Account): void }) {
  const { companyId } = useAuth();
  const [sel, setSel] = useState<string | null>(null);
  const selected = accounts.find((a) => a.id === sel) ?? null;
  const mv = useQuerySnapshot(() => (companyId && sel ? accountMovementsQuery(companyId, sel, 100) : null), [companyId, sel], accountMovementFromDoc);
  const rows = useMemo(() => [...mv.data].sort((a, b) => b.date.localeCompare(a.date) || b.createdAtMs - a.createdAtMs), [mv.data]);
  if (loading) return <LoadingState />;
  if (error) return <ErrorState error={error} />;
  if (accounts.length === 0) return <EmptyState text={t('cashBank.noAccounts')} />;
  return (
    <div className="split">
      <div className="card list">
        {accounts.map((a) => (
          <div key={a.id} className={`list-item ${a.id === sel ? 'sel' : ''}`} onClick={() => setSel(a.id)}>
            <div className="grow"><div className="name">{a.name}{!a.active && <> <Chip color="var(--c-neutral)">{t('common.passive')}</Chip></>}</div>
              <div className="sub">{t(`cashBank.${a.type}`)}{a.bankName && ` · ${a.bankName}`}</div></div>
            <Balance minor={a.balanceMinor} bold />
          </div>))}
      </div>
      <div className="card detail">
        {!selected ? <EmptyState text={t('cashBank.movements')} /> : (<>
          <div className="page-head"><h3 style={{ margin: 0 }}>{selected.name}</h3><div className="spacer" />
            {canWrite && <button className="btn secondary sm" onClick={() => onEdit(selected)}><Pencil size={14} />{t('common.edit')}</button>}</div>
          {mv.loading ? <LoadingState /> : rows.length === 0 ? <EmptyState text={t('cashBank.noMovements')} /> : (
            <table className="tbl"><thead><tr><th>{t('invoiceColumns.date')}</th><th>{t('invoiceColumns.type')}</th><th className="num">{t('payment.amount')}</th></tr></thead>
              <tbody>{rows.map((m) => (
                <tr key={m.id}><td>{formatDateTr(m.date)}</td><td>{t(`ledger.${m.refType}`) === `ledger.${m.refType}` ? m.refType : t(`ledger.${m.refType}`)}</td>
                  <td className={`num money ${m.deltaMinor >= 0 ? 'pos' : 'neg'}`}>{m.deltaMinor > 0 ? '+' : '−'}{formatMinorTry(Math.abs(m.deltaMinor))}</td></tr>))}</tbody></table>)}
        </>)}
      </div>
    </div>
  );
}

export function PaymentsTab({ parties, accounts, canWrite, partyId, direction }: { parties: { id: string; name: string }[]; accounts: Account[]; canWrite: boolean; partyId?: string; direction?: PaymentDirection }) {
  const { companyId, can, state } = useAuth();
  const toast = useToast();
  const snap = useQuerySnapshot(() => (companyId ? paymentsQuery(companyId, 100) : null), [companyId], paymentFromDoc);
  const [cancelId, setCancelId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const txId = useRef(newId());
  const pName = useMemo(() => new Map(parties.map((p) => [p.id, p.name])), [parties]);
  const aName = useMemo(() => new Map(accounts.map((a) => [a.id, a.name])), [accounts]);
  const rows: Payment[] = snap.data.filter((p) => (!partyId || p.partyId === partyId) && (!direction || p.direction === direction));

  const doCancel = async () => {
    try {
      await cancelPayment({ companyId: companyId!, uid: state.status === 'ready' ? state.user.uid : '', can }, cancelId!, txId.current);
      toast('success', t('payment.cancelledMsg')); setCancelId(null); txId.current = newId();
    } catch (e) { setCancelId(null); setError(txErrorMessage(e)); }
  };
  if (snap.loading) return <LoadingState />;
  if (snap.error) return <ErrorState error={snap.error} />;
  if (rows.length === 0) return <EmptyState />;
  return (
    <div className="card table-wrap">
      {error && <div className="error" role="alert">{error}</div>}
      <table className="tbl"><thead><tr><th>{t('payment.date')}</th><th>{t('invoice.party')}</th><th>{t('payment.direction')}</th><th>{t('cashBank.account')}</th>
        <th>{t('payment.method')}</th><th className="num">{t('payment.amount')}</th><th /></tr></thead>
        <tbody>{rows.map((p) => (
          <tr key={p.id}><td>{formatDateTr(p.date)}</td><td>{pName.get(p.partyId) ?? ''}</td><td>{t(`payment.${p.direction}`)}</td><td>{aName.get(p.accountId) ?? ''}</td>
            <td>{t(`payment.methods.${p.method}`)}</td>
            <td className={`num money ${p.direction === 'in' ? 'pos' : 'neg'}`}>{formatMinorTry(p.amountMinor)}</td>
            <td>{p.status === 'cancelled' ? <Chip color="var(--c-neutral)">{t('payment.cancelled')}</Chip>
              : canWrite && <button className="btn secondary sm" onClick={() => { setError(null); setCancelId(p.id); }}>{t('payment.cancel')}</button>}</td></tr>))}</tbody></table>
      {cancelId && <Dialog title={t('payment.cancel')} onClose={() => setCancelId(null)} width={440}
        footer={<><button className="btn secondary" onClick={() => setCancelId(null)}>{t('common.cancel')}</button><button className="btn" onClick={doCancel}>{t('common.confirm')}</button></>}>{t('payment.confirmCancel')}</Dialog>}
    </div>
  );
}
