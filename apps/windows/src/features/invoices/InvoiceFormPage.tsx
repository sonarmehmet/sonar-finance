import { useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { Plus, Printer, Trash2 } from 'lucide-react';
import { t } from '@/core/i18n';
import { useAuth } from '@/core/auth/AuthProvider';
import { useQuerySnapshot } from '@/core/hooks/useSnapshot';
import { useDocSnapshot } from '@/core/hooks/useDocSnapshot';
import { newId } from '@/core/id';
import { addDays } from '@/core/dates';
import { formatBp, formatMilli, formatMinor, formatMinorTry, parseMilli, parseMinor, todayIso } from '@/core/money';
import { calculateLine, calculateTotals } from '@/core/calc/invoiceCalculator';
import constants from '@shared/constants.json';
import {
  INVOICE_TYPES, invoiceFromData, partyKindFor, toDraft, defaultDueDate, lineInput,
  type InvoiceDraft, type InvoiceLine, type InvoiceType,
} from '@/data/invoice';
import { invoiceRef, partiesQuery, productsQuery, projectsQuery, warehousesQuery } from '@/data/repositories';
import { projectFromDoc } from '@/data/projects';
import { partyFromDoc, productFromDoc, warehouseFromDoc } from '@/data/models';
import { deleteDraft, issueInvoice, saveDraft } from '@/services/invoiceService';
import { TxError, txErrorMessage } from '@/services/txErrors';
import { Dialog } from '@/components/Dialog';
import { useToast } from '@/components/Toast';
import { ErrorState, LoadingState } from '@/components/ui';

const blankDraft = (type: InvoiceType): InvoiceDraft => ({
  type, partyId: '', partyName: '', issueDate: todayIso(), dueDate: defaultDueDate(todayIso()),
  priceIncludesVat: false, note: '', lines: [], rev: 0,
});

/** Düzenlenebilir satır (metin alanları ham girdi tutar). */
interface Row { key: string; line: InvoiceLine; qty: string; price: string; disc: string }
const toRow = (l: InvoiceLine): Row => ({ key: l.lineId, line: l, qty: formatMilli(l.qtyMilli), price: formatMinor(l.unitPriceMinor), disc: l.discountBp ? formatBp(l.discountBp).replace(/[%\s]/g, '') : '' });

export function InvoiceFormPage() {
  const { id } = useParams();
  const { companyId } = useAuth();
  const ref = companyId && id ? invoiceRef(companyId, id) : null;
  const doc = useDocSnapshot(ref, `${companyId}/${id}`, invoiceFromData);
  if (id && doc.loading) return <LoadingState />;
  if (id && doc.error) return <ErrorState error={doc.error} />;
  if (id && !doc.data) return <div className="empty">{t('errors.invoiceNotFound')}</div>;
  return <InvoiceForm key={id ?? 'new'} initial={doc.data ? toDraft(doc.data) : null} />;
}

function InvoiceForm({ initial }: { initial: InvoiceDraft | null }) {
  const { companyId, can, state } = useAuth();
  const navigate = useNavigate();
  const toast = useToast();
  const uid = state.status === 'ready' ? state.user.uid : '';
  const defaultVat = (state.status === 'ready' && state.company.settings?.defaultVatBp) || 2000;
  const parties = useQuerySnapshot(() => (companyId ? partiesQuery(companyId) : null), [companyId], partyFromDoc);
  const products = useQuerySnapshot(() => (companyId ? productsQuery(companyId) : null), [companyId], productFromDoc);
  const projects = useQuerySnapshot(() => (companyId ? projectsQuery(companyId) : null), [companyId], projectFromDoc);
  const warehouses = useQuerySnapshot(() => (companyId ? warehousesQuery(companyId) : null), [companyId], warehouseFromDoc);

  const base = useMemo(() => initial ?? blankDraft('sales'), [initial, defaultVat]);
  const [type, setType] = useState<InvoiceType>(base.type);
  const [partyId, setPartyId] = useState(base.partyId);
  const [issueDate, setIssueDate] = useState(base.issueDate);
  const [dueDate, setDueDate] = useState(base.dueDate);
  const [inclVat, setInclVat] = useState(base.priceIncludesVat);
  const [note, setNote] = useState(base.note);
  const [projectId, setProjectId] = useState(base.projectId ?? '');
  const [costCategory, setCostCategory] = useState(base.costCategory ?? '');
  const [rows, setRows] = useState<Row[]>(base.lines.map(toRow));
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [conflict, setConflict] = useState(false);
  const [confirm, setConfirm] = useState(false);
  const txId = useRef(newId()); // form başına bir kez: yeniden denemede AYNI txId (çift kayıt olmaz)
  const rev = useRef(base.rev);

  const party = parties.data.find((p) => p.id === partyId);
  const defaultWh = warehouses.data.find((w) => w.isDefault && w.active)?.id ?? warehouses.data.find((w) => w.active)?.id;
  const canWrite = can('invoice.write');

  // Satırları parse edip hesapla (UI toplamı; asıl hesap serviste yeniden yapılır).
  const parsed = rows.map((r) => {
    const q = parseMilli(r.qty), p = parseMinor(r.price);
    const d = r.disc.trim() === '' ? 0 : Math.round(Number(r.disc.replace(',', '.')) * 100);
    const ok = q !== null && p !== null && Number.isFinite(d);
    const line: InvoiceLine = { ...r.line, qtyMilli: q ?? 0, unitPriceMinor: p ?? 0, discountBp: Number.isFinite(d) ? d : 0 };
    return { ok, line, amounts: calculateLine(lineInput(line), inclVat) };
  });
  const totals = calculateTotals(parsed.map((p) => p.amounts));

  const draft = (): InvoiceDraft => ({
    id: initial?.id, type, partyId, partyName: party?.name ?? initial?.partyName ?? '', issueDate, dueDate,
    projectId: projectId || undefined, costCategory: projectId && costCategory ? costCategory : undefined, priceIncludesVat: inclVat, note,
    lines: parsed.map((p) => p.line), rev: rev.current,
  });

  const patch = (key: string, f: (r: Row) => Row) => setRows((rs) => rs.map((r) => (r.key === key ? f(r) : r)));
  const addRow = () => setRows((rs) => [...rs, toRow({
    lineId: newId(), description: '', qtyMilli: 1000, unit: 'adet', unitPriceMinor: 0, discountBp: 0, vatBp: defaultVat,
    netMinor: 0, discountMinor: 0, vatMinor: 0, totalMinor: 0,
  })]);
  const pickProduct = (key: string, pid: string) => {
    const p = products.data.find((x) => x.id === pid);
    patch(key, (r) => {
      if (!p) return { ...r, line: { ...r.line, productId: undefined, warehouseId: undefined } };
      const price = type === 'sales' || type === 'sales_return' ? p.sellPriceMinor : p.buyPriceMinor;
      return { ...r, price: formatMinor(price), line: {
        ...r.line, productId: p.id, description: r.line.description || p.name, unit: p.unit, vatBp: p.vatBp,
        warehouseId: p.trackStock ? (r.line.warehouseId ?? defaultWh) : undefined, unitPriceMinor: price } };
    });
  };

  const run = async (fn: () => Promise<void>) => {
    setBusy(true); setError(null);
    try { await fn(); } catch (e) {
      if (e instanceof TxError && e.code === 'draftChanged') setConflict(true); else setError(txErrorMessage(e));
    } finally { setBusy(false); }
  };
  const ctx = { companyId: companyId!, uid, can: (p: 'invoice.write') => can(p) };

  const onSaveDraft = () => run(async () => {
    const r = await saveDraft(ctx, draft());
    toast('success', r.synced ? t('invoice.draftSaved') : t('messages.queued'));
    navigate('/invoices');
  });
  const onIssue = (force = false) => run(async () => {
    setConfirm(false); setConflict(false);
    const r = await issueInvoice(ctx, draft(), txId.current, force);
    toast('success', t('messages.invoiceIssued', { number: r.number }));
    navigate(`/invoices/${r.invoiceId}`);
  });
  const onDelete = () => run(async () => {
    if (!initial?.id || !window.confirm(t('invoice.confirmDeleteDraft'))) return;
    await deleteDraft(ctx, initial.id);
    toast('success', t('invoice.draftDeleted'));
    navigate('/invoices');
  });

  useEffect(() => { // vade tarihi fatura tarihinden önce kalmasın
    if (dueDate < issueDate) setDueDate(addDays(issueDate, 30));
  }, [issueDate, dueDate]);

  const kind = partyKindFor(type);
  const partyOptions = parties.data.filter((p) => p.active && p.kinds.includes(kind));
  const offline = typeof navigator !== 'undefined' && !navigator.onLine;

  return (
    <div className="invoice-form">
      <div className="page-head">
        <h2 style={{ margin: 0 }}>{initial?.id ? t('invoice.editDraft') : t('invoiceForm.newInvoice')}</h2>
        <div className="spacer" />
        <button className="btn secondary" onClick={() => window.print()}><Printer size={16} />{t('invoiceForm.print')}</button>
      </div>
      {error && <div className="error" role="alert">{error}</div>}
      {offline && <div className="error">{t('invoice.offlineDraftOnly')}</div>}

      <div className="card" style={{ marginBottom: 'var(--s-lg)' }}>
        <h3 style={{ marginTop: 0 }}>{t('invoiceForm.info')}</h3>
        <div className="grid2">
          <div className="field"><label>{t('invoice.type')}</label>
            <select value={type} disabled={!!initial?.id} onChange={(e) => { setType(e.target.value as InvoiceType); setPartyId(''); }}>
              {INVOICE_TYPES.map((x) => <option key={x} value={x}>{t(`invoiceType.${x}`)}</option>)}
            </select></div>
          <div className="field"><label>{t('invoice.party')}</label>
            <select value={partyId} onChange={(e) => setPartyId(e.target.value)}>
              <option value="">{t('invoice.selectParty')}</option>
              {partyOptions.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
            </select></div>
          <div className="field"><label>{t('invoiceForm.invoiceDate')}</label><input type="date" value={issueDate} onChange={(e) => setIssueDate(e.target.value)} /></div>
          <div className="field"><label>{t('invoiceForm.dueDate')}</label><input type="date" value={dueDate} min={issueDate} onChange={(e) => setDueDate(e.target.value)} /></div>
        </div>
        <div className="grid2">
          <div className="field"><label>{t('menu.projects')}</label><select value={projectId} onChange={(e) => setProjectId(e.target.value)}>
            <option value="" />{projects.data.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}</select></div>
          {projectId && (type === 'purchase' || type === 'purchase_return') && (
            <div className="field"><label>{t('expense.discipline')}</label><select value={costCategory} onChange={(e) => setCostCategory(e.target.value)}>
              <option value="" />{constants.disciplines.map((d) => <option key={d} value={d}>{t(`disciplines.${d}`)}</option>)}</select></div>)}
        </div>
        <label className="check"><input type="checkbox" checked={inclVat} onChange={(e) => setInclVat(e.target.checked)} />{t('invoiceForm.priceIncludesVat')}</label>
        <div className="field"><label>{t('invoice.note')}</label><textarea rows={2} value={note} onChange={(e) => setNote(e.target.value)} /></div>
      </div>

      <div className="card" style={{ marginBottom: 'var(--s-lg)' }}>
        <div style={{ display: 'flex', alignItems: 'center', marginBottom: 'var(--s-md)' }}>
          <h3 style={{ margin: 0 }}>{t('invoiceForm.lines')}</h3><div className="spacer" />
          <button className="btn sm" onClick={addRow}><Plus size={14} />{t('invoiceForm.addLine')}</button>
        </div>
        {rows.length === 0 ? <div className="empty">{t('invoice.noLines')}</div> : (
          <div className="table-wrap"><table className="tbl">
            <thead><tr>
              <th>{t('invoiceForm.product')}</th><th>{t('invoiceForm.description')}</th><th>{t('invoiceForm.warehouse')}</th>
              <th className="num">{t('invoiceForm.quantity')}</th><th className="num">{t('invoiceForm.unitPrice')}</th>
              <th className="num">{t('invoice.discountPct')}</th><th>{t('invoiceForm.vat')}</th><th className="num">{t('invoiceForm.lineTotal')}</th><th />
            </tr></thead>
            <tbody>{rows.map((r, i) => {
              const prod = products.data.find((x) => x.id === r.line.productId);
              const bad = !parsed[i].ok;
              return (
                <tr key={r.key}>
                  <td><select value={r.line.productId ?? ''} onChange={(e) => pickProduct(r.key, e.target.value)}>
                    <option value="">{t('invoice.selectProduct')}</option>
                    {products.data.filter((p) => p.active).map((p) => <option key={p.id} value={p.id}>{p.code ? `${p.code} · ` : ''}{p.name}</option>)}
                  </select></td>
                  <td><input value={r.line.description} onChange={(e) => patch(r.key, (x) => ({ ...x, line: { ...x.line, description: e.target.value } }))} /></td>
                  <td>{prod?.trackStock ? (
                    <select value={r.line.warehouseId ?? ''} title={t('invoice.stockWarehouseHint')} onChange={(e) => patch(r.key, (x) => ({ ...x, line: { ...x.line, warehouseId: e.target.value || undefined } }))}>
                      <option value="" />{warehouses.data.filter((w) => w.active).map((w) => <option key={w.id} value={w.id}>{w.name}</option>)}
                    </select>) : '—'}</td>
                  <td className="num"><input style={{ width: 80, textAlign: 'right', borderColor: bad ? 'var(--c-negative)' : undefined }} value={r.qty} onChange={(e) => patch(r.key, (x) => ({ ...x, qty: e.target.value }))} /></td>
                  <td className="num"><input style={{ width: 110, textAlign: 'right' }} value={r.price} onChange={(e) => patch(r.key, (x) => ({ ...x, price: e.target.value }))} /></td>
                  <td className="num"><input style={{ width: 60, textAlign: 'right' }} value={r.disc} onChange={(e) => patch(r.key, (x) => ({ ...x, disc: e.target.value }))} /></td>
                  <td><select value={r.line.vatBp} onChange={(e) => patch(r.key, (x) => ({ ...x, line: { ...x.line, vatBp: Number(e.target.value) } }))}>
                    {constants.vatRatesBp.map((v) => <option key={v} value={v}>%{v / 100}</option>)}
                  </select></td>
                  <td className="num money">{formatMinorTry(parsed[i].amounts.totalMinor)}</td>
                  <td><button className="icon-btn" title={t('invoice.removeLine')} onClick={() => setRows((rs) => rs.filter((x) => x.key !== r.key))}><Trash2 size={16} /></button></td>
                </tr>);
            })}</tbody>
          </table></div>
        )}
      </div>

      <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
        <div className="card" style={{ minWidth: 340 }}>
          <h3 style={{ marginTop: 0 }}>{t('invoiceForm.totals')}</h3>
          {([['invoiceForm.subtotal', totals.subtotalMinor], ['invoiceForm.discountTotal', totals.discountMinor], ['invoiceForm.vatTotal', totals.vatMinor]] as [string, number][]).map(([k, v]) => (
            <div key={k} style={{ display: 'flex', justifyContent: 'space-between', padding: '4px 0' }}><span>{t(k)}</span><span className="money">{formatMinorTry(v)}</span></div>))}
          <div style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 0', fontWeight: 600, fontSize: 'var(--fs-title)' }}>
            <span>{t('invoiceForm.grandTotal')}</span><span className="money">{formatMinorTry(totals.totalMinor)}</span></div>
          {canWrite && (
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginTop: 8 }}>
              <button className="btn secondary" disabled={busy} onClick={onSaveDraft}>{t('invoiceForm.saveDraft')}</button>
              <button className="btn" disabled={busy || offline} onClick={() => setConfirm(true)}>{t('invoiceForm.issue')}</button>
              {initial?.id && <button className="btn secondary" disabled={busy} onClick={onDelete}>{t('common.delete')}</button>}
            </div>)}
        </div>
      </div>

      {confirm && (
        <Dialog title={t('invoiceForm.issue')} onClose={() => setConfirm(false)} width={440}
          footer={<><button className="btn secondary" onClick={() => setConfirm(false)}>{t('common.cancel')}</button><button className="btn" onClick={() => onIssue(false)}>{t('common.confirm')}</button></>}>
          {t('invoice.confirmIssue')}
        </Dialog>)}
      {conflict && (
        <Dialog title={t('invoice.draftChangedTitle')} onClose={() => setConflict(false)} width={460}
          footer={<>
            <button className="btn secondary" onClick={() => { setConflict(false); navigate(`/invoices/${initial?.id}/edit`, { replace: true }); window.location.reload(); }}>{t('invoice.openServer')}</button>
            <button className="btn" onClick={() => onIssue(true)}>{t('invoice.keepMine')}</button></>}>
          {t('errors.draftChanged')}
        </Dialog>)}
    </div>
  );
}
