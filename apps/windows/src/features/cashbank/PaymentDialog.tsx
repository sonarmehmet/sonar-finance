import { useMemo, useRef, useState } from 'react';
import { t } from '@/core/i18n';
import { useAuth } from '@/core/auth/AuthProvider';
import { useQuerySnapshot } from '@/core/hooks/useSnapshot';
import { newId } from '@/core/id';
import { formatDateTr } from '@/core/dates';
import { formatMinor, formatMinorTry, parseMinor, todayIso } from '@/core/money';
import { invoiceFromDoc, remainingMinor } from '@/data/invoice';
import { partyInvoicesQuery } from '@/data/repositories';
import type { Account, PaymentDirection, PaymentMethod } from '@/data/finance';
import type { Party } from '@/data/models';
import { recordPayment } from '@/services/paymentService';
import { txErrorMessage } from '@/services/txErrors';
import { Dialog } from '@/components/Dialog';
import { useToast } from '@/components/Toast';

const METHODS: PaymentMethod[] = ['cash', 'bank_transfer', 'cheque', 'card'];

export function PaymentDialog({ direction, parties, accounts, partyId, onClose }: {
  direction: PaymentDirection; parties: Party[]; accounts: Account[]; partyId?: string; onClose(): void;
}) {
  const { companyId, can, state } = useAuth();
  const toast = useToast();
  const activeAcc = accounts.filter((a) => a.active);
  const [pid, setPid] = useState(partyId ?? '');
  const [accId, setAccId] = useState(activeAcc[0]?.id ?? '');
  const [amount, setAmount] = useState('');
  const [date, setDate] = useState(todayIso());
  const [method, setMethod] = useState<PaymentMethod>('cash');
  const [note, setNote] = useState('');
  const [alloc, setAlloc] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const txId = useRef(newId());

  const invs = useQuerySnapshot(() => (companyId && pid ? partyInvoicesQuery(companyId, pid) : null), [companyId, pid], invoiceFromDoc);
  const open = useMemo(() => invs.data
    .filter((i) => i.status === 'issued' && remainingMinor(i) > 0 && (direction === 'in' ? i.type === 'sales' || i.type === 'purchase_return' : i.type === 'purchase' || i.type === 'sales_return'))
    .sort((a, b) => a.dueDate.localeCompare(b.dueDate)), [invs.data, direction]);

  const amountMinor = parseMinor(amount) ?? 0;
  const allocMinor = (id: string) => parseMinor(alloc[id] ?? '') ?? 0;
  const allocSum = open.reduce((s, i) => s + allocMinor(i.id), 0);

  const auto = () => { // en eski vadeden başlayarak dağıt
    let left = amountMinor; const next: Record<string, string> = {};
    for (const i of open) { const a = Math.min(left, remainingMinor(i)); if (a > 0) next[i.id] = formatMinor(a); left -= a; }
    setAlloc(next);
  };

  const submit = async () => {
    setBusy(true); setError(null);
    try {
      await recordPayment({ companyId: companyId!, uid: state.status === 'ready' ? state.user.uid : '', can }, {
        txId: txId.current, direction, partyId: pid, accountId: accId, amountMinor, date, method, note,
        allocations: open.map((i) => ({ invoiceId: i.id, amountMinor: allocMinor(i.id) })).filter((a) => a.amountMinor > 0),
      });
      toast('success', t('messages.paymentSaved'));
      onClose();
    } catch (e) { setError(txErrorMessage(e)); } finally { setBusy(false); }
  };

  return (
    <Dialog title={t(direction === 'in' ? 'payment.newCollection' : 'payment.newPayment')} onClose={onClose} width={640}
      footer={<><button className="btn secondary" onClick={onClose}>{t('common.cancel')}</button>
        <button className="btn" disabled={busy || !pid || amountMinor <= 0 || allocSum > amountMinor} onClick={submit}>{t('common.save')}</button></>}>
      {error && <div className="error" role="alert">{error}</div>}
      <div className="grid2">
        <div className="field"><label>{t('invoice.party')}</label>
          <select value={pid} disabled={!!partyId} onChange={(e) => { setPid(e.target.value); setAlloc({}); }}>
            <option value="">{t('invoice.selectParty')}</option>{parties.filter((p) => p.active).map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}</select></div>
        <div className="field"><label>{t('cashBank.account')}</label>
          <select value={accId} onChange={(e) => setAccId(e.target.value)}>
            <option value="">{t('cashBank.selectAccount')}</option>{activeAcc.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}</select></div>
        <div className="field"><label>{t('payment.amount')}</label><input value={amount} onChange={(e) => setAmount(e.target.value)} inputMode="decimal" /></div>
        <div className="field"><label>{t('payment.date')}</label><input type="date" value={date} onChange={(e) => setDate(e.target.value)} /></div>
        <div className="field"><label>{t('payment.method')}</label>
          <select value={method} onChange={(e) => setMethod(e.target.value as PaymentMethod)}>{METHODS.map((m) => <option key={m} value={m}>{t(`payment.methods.${m}`)}</option>)}</select></div>
        <div className="field"><label>{t('payment.note')}</label><input value={note} onChange={(e) => setNote(e.target.value)} /></div>
      </div>
      {pid && (
        <>
          <div style={{ display: 'flex', alignItems: 'center', marginBottom: 8 }}>
            <strong>{t('payment.allocations')}</strong><div className="spacer" />
            <button className="btn secondary sm" onClick={auto} disabled={amountMinor <= 0}>{t('payment.autoAllocate')}</button>
          </div>
          {open.length === 0 ? <div className="sub">{t('payment.noOpenInvoices')}</div> : (
            <table className="tbl"><tbody>{open.map((i) => (
              <tr key={i.id}><td>{i.number}</td><td>{formatDateTr(i.dueDate)}</td><td className="num money">{formatMinorTry(remainingMinor(i))}</td>
                <td className="num"><input style={{ width: 110, textAlign: 'right' }} value={alloc[i.id] ?? ''} onChange={(e) => setAlloc({ ...alloc, [i.id]: e.target.value })} /></td></tr>))}</tbody></table>)}
          <div className="sub" style={{ marginTop: 8 }}>{t('payment.unallocated')}: {formatMinorTry(Math.max(0, amountMinor - allocSum))}</div>
        </>)}
    </Dialog>
  );
}
