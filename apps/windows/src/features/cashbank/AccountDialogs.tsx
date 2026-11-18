import { useRef, useState } from 'react';
import { t } from '@/core/i18n';
import { useAuth } from '@/core/auth/AuthProvider';
import { newId } from '@/core/id';
import { formatMinor, parseMinor, todayIso } from '@/core/money';
import type { Account, AccountType } from '@/data/finance';
import { createAccount, transferBetweenAccounts, updateAccount } from '@/services/paymentService';
import { txErrorMessage } from '@/services/txErrors';
import { Dialog } from '@/components/Dialog';
import { useToast } from '@/components/Toast';

const useCtx = () => {
  const { companyId, can, state } = useAuth();
  return { companyId: companyId!, uid: state.status === 'ready' ? state.user.uid : '', can };
};

export function AccountForm({ account, type, onClose }: { account?: Account; type: AccountType; onClose(): void }) {
  const ctx = useCtx();
  const toast = useToast();
  const [name, setName] = useState(account?.name ?? '');
  const [bankName, setBankName] = useState(account?.bankName ?? '');
  const [iban, setIban] = useState(account?.iban ?? '');
  const [opening, setOpening] = useState('');
  const [active, setActive] = useState(account?.active ?? true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const isBank = (account?.type ?? type) === 'bank';

  const save = async () => {
    setBusy(true); setError(null);
    try {
      if (account) await updateAccount(ctx, account.id, { name, bankName, iban, active });
      else {
        const o = opening.trim() === '' ? 0 : parseMinor(opening);
        if (o === null) throw new Error('x');
        await createAccount(ctx, { type, name, bankName, iban }, o);
      }
      toast('success', t('payment.accountSaved'));
      onClose();
    } catch (e) { setError(e instanceof Error && e.message === 'x' ? t('validation.invalidAmount') : txErrorMessage(e)); } finally { setBusy(false); }
  };
  return (
    <Dialog title={account ? t('cashBank.editAccount') : t(type === 'bank' ? 'cashBank.newBank' : 'cashBank.newCash')} onClose={onClose} width={460}
      footer={<><button className="btn secondary" onClick={onClose}>{t('common.cancel')}</button><button className="btn" disabled={busy} onClick={save}>{t('common.save')}</button></>}>
      {error && <div className="error" role="alert">{error}</div>}
      <div className="field"><label>{t('stock.name')}</label><input value={name} onChange={(e) => setName(e.target.value)} /></div>
      {isBank && <>
        <div className="field"><label>{t('cashBank.bankName')}</label><input value={bankName} onChange={(e) => setBankName(e.target.value)} /></div>
        <div className="field"><label>{t('cashBank.iban')}</label><input value={iban} onChange={(e) => setIban(e.target.value)} /></div></>}
      {!account && <div className="field"><label>{t('cashBank.openingBalance')}</label><input value={opening} placeholder={formatMinor(0)} onChange={(e) => setOpening(e.target.value)} inputMode="decimal" /></div>}
      {account && <label className="check"><input type="checkbox" checked={active} onChange={(e) => setActive(e.target.checked)} />{t('fields.active')}</label>}
    </Dialog>
  );
}

export function TransferDialog({ accounts, onClose }: { accounts: Account[]; onClose(): void }) {
  const ctx = useCtx();
  const toast = useToast();
  const act = accounts.filter((a) => a.active);
  const [from, setFrom] = useState(act[0]?.id ?? '');
  const [to, setTo] = useState('');
  const [amount, setAmount] = useState('');
  const [date, setDate] = useState(todayIso());
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const txId = useRef(newId());

  const save = async () => {
    setBusy(true); setError(null);
    try {
      await transferBetweenAccounts(ctx, { txId: txId.current, fromId: from, toId: to, amountMinor: parseMinor(amount) ?? 0, date, note });
      toast('success', t('payment.transferDone'));
      onClose();
    } catch (e) { setError(txErrorMessage(e)); } finally { setBusy(false); }
  };
  return (
    <Dialog title={t('cashBank.transfer')} onClose={onClose} width={460}
      footer={<><button className="btn secondary" onClick={onClose}>{t('common.cancel')}</button><button className="btn" disabled={busy} onClick={save}>{t('common.save')}</button></>}>
      {error && <div className="error" role="alert">{error}</div>}
      <div className="grid2">
        <div className="field"><label>{t('cashBank.fromAccount')}</label><select value={from} onChange={(e) => setFrom(e.target.value)}>{act.map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}</select></div>
        <div className="field"><label>{t('cashBank.toAccount')}</label><select value={to} onChange={(e) => setTo(e.target.value)}><option value="" />{act.filter((a) => a.id !== from).map((a) => <option key={a.id} value={a.id}>{a.name}</option>)}</select></div>
        <div className="field"><label>{t('payment.amount')}</label><input value={amount} onChange={(e) => setAmount(e.target.value)} inputMode="decimal" /></div>
        <div className="field"><label>{t('payment.date')}</label><input type="date" value={date} onChange={(e) => setDate(e.target.value)} /></div>
      </div>
      <div className="field"><label>{t('payment.note')}</label><input value={note} onChange={(e) => setNote(e.target.value)} /></div>
    </Dialog>
  );
}
