import { useRef, useState } from 'react';
import { t } from '@/core/i18n';
import { useAuth } from '@/core/auth/AuthProvider';
import { newId } from '@/core/id';
import { formatMilli, formatMinor, parseMilli, parseMinor } from '@/core/money';
import type { Product, StockLevel, Warehouse } from '@/data/models';
import { stockCount, stockIn, stockOut, stockTransfer } from '@/services/stockService';
import { TxError, txErrorMessage } from '@/services/txErrors';
import { Dialog } from '@/components/Dialog';
import { useToast } from '@/components/Toast';

export type StockAction = 'in' | 'out' | 'adjust' | 'transfer';
const TITLE: Record<StockAction, string> = { in: 'stock.stockIn', out: 'stock.stockOut', adjust: 'stock.adjust', transfer: 'stock.transfer' };

export function StockActionDialog({ action, products, warehouses, levels, productId, onClose }: {
  action: StockAction; products: Product[]; warehouses: Warehouse[]; levels: StockLevel[]; productId?: string; onClose(): void;
}) {
  const { companyId, can, state } = useAuth();
  const toast = useToast();
  const tracked = products.filter((p) => p.active && p.trackStock);
  const whs = warehouses.filter((w) => w.active);
  const [pid, setPid] = useState(productId ?? '');
  const [wh, setWh] = useState(whs.find((w) => w.isDefault)?.id ?? whs[0]?.id ?? '');
  const [toWh, setToWh] = useState('');
  const [qty, setQty] = useState('');
  const [cost, setCost] = useState('');
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const txId = useRef(newId()); // aynı form → aynı txId (çift kayıt olmaz)

  const product = tracked.find((p) => p.id === pid);
  const current = levels.find((l) => l.productId === pid && l.warehouseId === wh)?.qtyMilli ?? 0;
  const needsReason = action === 'out' || action === 'adjust';

  const submit = async () => {
    setError(null);
    const q = parseMilli(qty);
    if (!pid || !wh) { setError(t('validation.required')); return; }
    if (q === null || (action !== 'adjust' && q <= 0) || q < 0) { setError(t('errors.invalidQty')); return; }
    setBusy(true);
    try {
      const ctx = { companyId: companyId!, uid: state.status === 'ready' ? state.user.uid : '', can };
      const id = txId.current;
      if (action === 'in') {
        const c = cost.trim() === '' ? (product?.avgCostMinor ?? 0) : parseMinor(cost);
        if (c === null) throw new TxError('invalidAmount');
        await stockIn(ctx, { txId: id, productId: pid, warehouseId: wh, qtyMilli: q, unitCostMinor: c, note: reason });
      } else if (action === 'out') {
        await stockOut(ctx, { txId: id, productId: pid, warehouseId: wh, qtyMilli: q, reason });
      } else if (action === 'adjust') {
        await stockCount(ctx, { txId: id, productId: pid, warehouseId: wh, countedMilli: q, reason });
      } else {
        await stockTransfer(ctx, { txId: id, productId: pid, fromWarehouseId: wh, toWarehouseId: toWh, qtyMilli: q, note: reason });
      }
      toast('success', t('stock.done'));
      onClose();
    } catch (e) { setError(txErrorMessage(e)); } finally { setBusy(false); }
  };

  return (
    <Dialog title={t(TITLE[action])} onClose={onClose} width={480}
      footer={<><button className="btn secondary" onClick={onClose}>{t('common.cancel')}</button>
        <button className="btn" disabled={busy} onClick={submit}>{t('common.save')}</button></>}>
      {error && <div className="error" role="alert">{error}</div>}
      <div className="field"><label>{t('stock.name')}</label>
        <select value={pid} onChange={(e) => setPid(e.target.value)}>
          <option value="" />{tracked.map((p) => <option key={p.id} value={p.id}>{p.code ? `${p.code} · ` : ''}{p.name}</option>)}
        </select></div>
      <div className="grid2">
        <div className="field"><label>{action === 'transfer' ? t('stock.fromWarehouse') : t('stock.warehouse')}</label>
          <select value={wh} onChange={(e) => setWh(e.target.value)}>{whs.map((w) => <option key={w.id} value={w.id}>{w.name}</option>)}</select></div>
        {action === 'transfer' && (
          <div className="field"><label>{t('stock.toWarehouse')}</label>
            <select value={toWh} onChange={(e) => setToWh(e.target.value)}><option value="" />{whs.filter((w) => w.id !== wh).map((w) => <option key={w.id} value={w.id}>{w.name}</option>)}</select></div>)}
      </div>
      {pid && <div className="sub" style={{ marginBottom: 'var(--s-md)' }}>{t('stock.currentQty')}: {formatMilli(current)} {product ? t(`unit.${product.unit}`) : ''}</div>}
      <div className="grid2">
        <div className="field"><label>{action === 'adjust' ? t('stock.countedQty') : t('stock.quantity')}</label><input value={qty} onChange={(e) => setQty(e.target.value)} inputMode="decimal" /></div>
        {action === 'in' && (
          <div className="field"><label>{t('stock.unitCostHint')}</label>
            <input value={cost} placeholder={product ? formatMinor(product.avgCostMinor) : ''} onChange={(e) => setCost(e.target.value)} inputMode="decimal" /></div>)}
      </div>
      <div className="field"><label>{needsReason ? t('stock.reason') : t('stock.note')}</label>
        <input value={reason} onChange={(e) => setReason(e.target.value)} /></div>
    </Dialog>
  );
}
