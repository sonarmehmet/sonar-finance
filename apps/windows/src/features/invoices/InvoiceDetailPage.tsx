import { useRef, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { Pencil, Printer, XCircle } from 'lucide-react';
import { t } from '@/core/i18n';
import { useAuth } from '@/core/auth/AuthProvider';
import { useDocSnapshot } from '@/core/hooks/useDocSnapshot';
import { newId } from '@/core/id';
import { formatDateTr } from '@/core/dates';
import { formatBp, formatMilli, formatMinorTry } from '@/core/money';
import { invoiceFromData, remainingMinor } from '@/data/invoice';
import { invoiceRef } from '@/data/repositories';
import { cancelInvoice } from '@/services/invoiceService';
import { txErrorMessage } from '@/services/txErrors';
import { Dialog } from '@/components/Dialog';
import { useToast } from '@/components/Toast';
import { ErrorState, LoadingState } from '@/components/ui';
import { StatusChip } from './InvoicesPage';

export function InvoiceDetailPage() {
  const { id } = useParams();
  const { companyId, can, state } = useAuth();
  const navigate = useNavigate();
  const toast = useToast();
  const doc = useDocSnapshot(companyId && id ? invoiceRef(companyId, id) : null, `${companyId}/${id}`, invoiceFromData);
  const [confirm, setConfirm] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const txId = useRef(newId());

  if (doc.loading) return <LoadingState />;
  if (doc.error) return <ErrorState error={doc.error} />;
  const inv = doc.data;
  if (!inv) return <div className="empty">{t('errors.invoiceNotFound')}</div>;
  const hasPayment = inv.paidMinor > 0;

  const onCancel = async () => {
    setBusy(true); setError(null);
    try {
      await cancelInvoice({ companyId: companyId!, uid: state.status === 'ready' ? state.user.uid : '', can }, inv.id, txId.current);
      toast('success', t('messages.invoiceCancelled'));
      setConfirm(false);
    } catch (e) {
      setConfirm(false);
      setError(txErrorMessage(e));
    } finally { setBusy(false); }
  };

  return (
    <div>
      <div className="page-head">
        <h2 style={{ margin: 0 }}>{inv.number ?? t(`invoiceType.${inv.type}`)}</h2><StatusChip inv={inv} />
        <div className="spacer" />
        <button className="btn secondary" onClick={() => window.print()}><Printer size={16} />{t('invoiceForm.print')}</button>
        {inv.status === 'draft' && can('invoice.write') && <button className="btn" onClick={() => navigate(`/invoices/${inv.id}/edit`)}><Pencil size={16} />{t('common.edit')}</button>}
        {inv.status === 'issued' && can('invoice.write') && (
          <button className="btn secondary" disabled={hasPayment || busy} title={hasPayment ? t('messages.cannotCancelPaid') : undefined} onClick={() => setConfirm(true)}>
            <XCircle size={16} />{t('invoice.cancelInvoice')}</button>)}
      </div>
      {error && <div className="error" role="alert">{error}</div>}
      <div className="card" style={{ marginBottom: 'var(--s-lg)' }}>
        <div className="grid2">
          <div><div className="sub">{t('invoice.party')}</div><div>{inv.partyName}</div></div>
          <div><div className="sub">{t('invoice.type')}</div><div>{t(`invoiceType.${inv.type}`)}</div></div>
          <div><div className="sub">{t('invoiceForm.invoiceDate')}</div><div>{formatDateTr(inv.issueDate)}</div></div>
          <div><div className="sub">{t('invoiceForm.dueDate')}</div><div>{formatDateTr(inv.dueDate)}</div></div>
        </div>
        {inv.note && <p>{inv.note}</p>}
      </div>
      <div className="card table-wrap" style={{ marginBottom: 'var(--s-lg)' }}>
        <table className="tbl">
          <thead><tr><th>{t('invoiceForm.description')}</th><th className="num">{t('invoiceForm.quantity')}</th><th className="num">{t('invoiceForm.unitPrice')}</th>
            <th className="num">{t('invoiceForm.discount')}</th><th>{t('invoiceForm.vat')}</th><th className="num">{t('invoiceForm.lineTotal')}</th></tr></thead>
          <tbody>{inv.lines.map((l) => (
            <tr key={l.lineId}><td>{l.description}</td><td className="num">{formatMilli(l.qtyMilli)} {l.unit}</td>
              <td className="num money">{formatMinorTry(l.unitPriceMinor)}</td><td className="num">{l.discountBp ? formatBp(l.discountBp) : '—'}</td>
              <td>{formatBp(l.vatBp)}</td><td className="num money">{formatMinorTry(l.totalMinor)}</td></tr>))}</tbody>
        </table>
      </div>
      <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
        <div className="card" style={{ minWidth: 340 }}>
          {([['invoiceForm.subtotal', inv.subtotalMinor], ['invoiceForm.discountTotal', inv.discountMinor], ['invoiceForm.vatTotal', inv.vatMinor]] as [string, number][]).map(([k, v]) => (
            <div key={k} style={{ display: 'flex', justifyContent: 'space-between', padding: '4px 0' }}><span>{t(k)}</span><span className="money">{formatMinorTry(v)}</span></div>))}
          <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 0', fontWeight: 600 }}><span>{t('invoiceForm.grandTotal')}</span><span className="money">{formatMinorTry(inv.totalMinor)}</span></div>
          {inv.status === 'issued' && <>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}><span>{t('invoice.paid')}</span><span className="money">{formatMinorTry(inv.paidMinor)}</span></div>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}><span>{t('invoice.remaining')}</span><span className="money">{formatMinorTry(remainingMinor(inv))}</span></div></>}
        </div>
      </div>
      {confirm && (
        <Dialog title={t('invoice.cancelInvoice')} onClose={() => setConfirm(false)} width={440}
          footer={<><button className="btn secondary" onClick={() => setConfirm(false)}>{t('common.cancel')}</button><button className="btn" disabled={busy} onClick={onCancel}>{t('common.confirm')}</button></>}>
          {t('messages.confirmCancelInvoice')}
        </Dialog>)}
    </div>
  );
}
