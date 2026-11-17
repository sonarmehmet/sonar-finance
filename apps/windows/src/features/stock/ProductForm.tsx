import { useMemo, useState } from 'react';
import { Dialog } from '@/components/Dialog';
import { useToast } from '@/components/Toast';
import { t } from '@/core/i18n';
import { useAuth } from '@/core/auth/AuthProvider';
import { formatBp, formatMilli, formatMinor, parseMilli, parseMinor } from '@/core/money';
import { productRepo } from '@/data/repositories';
import type { Product, ProductMaster, StockLevel, Warehouse } from '@/data/models';
import constants from '@shared/constants.json';

type Errors = Partial<Record<'code' | 'name' | 'buy' | 'sell' | 'min', string>>;

export function nextProductCode(products: Product[]): string {
  let max = 0;
  for (const p of products) { const m = /^PRD-(\d+)$/i.exec(p.code); if (m) max = Math.max(max, Number(m[1])); }
  return `PRD-${String(max + 1).padStart(4, '0')}`;
}

export function ProductForm({ product, products, levels, warehouses, readOnly, onClose }: {
  product?: Product; products: Product[]; levels: StockLevel[]; warehouses: Warehouse[]; readOnly?: boolean; onClose(): void;
}) {
  const { companyId } = useAuth();
  const toast = useToast();
  const [f, setF] = useState(() => ({
    code: product?.code ?? nextProductCode(products),
    name: product?.name ?? '',
    category: product?.category ?? '',
    unit: product?.unit ?? 'adet',
    vatBp: product?.vatBp ?? 2000,
    trackStock: product?.trackStock ?? true,
    buy: product ? formatMinor(product.buyPriceMinor) : '',
    sell: product ? formatMinor(product.sellPriceMinor) : '',
    min: product && product.minStockMilli ? formatMilli(product.minStockMilli) : '',
    barcode: product?.barcode ?? '',
    active: product?.active ?? true,
  }));
  const [errors, setErrors] = useState<Errors>({});
  const [busy, setBusy] = useState(false);
  const set = <K extends keyof typeof f>(k: K, v: (typeof f)[K]) => setF((s) => ({ ...s, [k]: v }));
  const whName = useMemo(() => new Map(warehouses.map((w) => [w.id, w.name])), [warehouses]);
  const myLevels = product ? levels.filter((l) => l.productId === product.id && l.qtyMilli !== 0) : [];

  async function save() {
    if (!companyId || readOnly) return;
    const e: Errors = {};
    const code = f.code.trim();
    if (!code) e.code = t('validation.required');
    else if (products.some((p) => p.id !== product?.id && p.code.toLocaleLowerCase('tr-TR') === code.toLocaleLowerCase('tr-TR'))) e.code = t('validation.duplicateCode');
    if (!f.name.trim()) e.name = t('validation.required');
    const buy = f.buy.trim() ? parseMinor(f.buy) : 0;
    const sell = f.sell.trim() ? parseMinor(f.sell) : 0;
    const min = f.min.trim() ? parseMilli(f.min) : 0;
    if (buy === null || buy < 0) e.buy = t('validation.invalidAmount');
    if (sell === null || sell < 0) e.sell = t('validation.invalidAmount');
    if (min === null || min < 0) e.min = t('validation.invalidQty');
    setErrors(e);
    if (Object.keys(e).length) return;

    const m: ProductMaster = {
      code, name: f.name.trim(), category: f.category.trim(), unit: f.unit, vatBp: f.vatBp, trackStock: f.trackStock,
      buyPriceMinor: buy!, sellPriceMinor: sell!, minStockMilli: min!, barcode: f.barcode.trim(), active: f.active,
    };
    setBusy(true);
    try {
      const synced = product ? await productRepo.update(companyId, product.id, m) : (await productRepo.create(companyId, m)).synced;
      toast(synced ? 'success' : 'info', synced ? t('messages.saved') : t('messages.queued'));
      onClose();
    } catch (err) {
      toast('error', `${t('messages.saveFailed')}: ${(err as Error).message}`);
    } finally {
      setBusy(false);
    }
  }

  const dis = !!readOnly;
  return (
    <Dialog title={product ? (readOnly ? product.name : t('stock.editProduct')) : t('stock.newProduct')} onClose={onClose} width={640}
      footer={<>
        <button className="btn secondary" onClick={onClose}>{readOnly ? t('common.close') : t('common.cancel')}</button>
        {!readOnly && <button className="btn" onClick={() => void save()} disabled={busy}>{t('common.save')}</button>}
      </>}>
      <div className="grid2">
        <div className={`field ${errors.code ? 'err' : ''}`}><label>{t('stock.code')}</label>
          <input value={f.code} disabled={dis} onChange={(e) => set('code', e.target.value)} />{errors.code && <span className="msg">{errors.code}</span>}</div>
        <div className={`field ${errors.name ? 'err' : ''}`}><label>{t('stock.name')}</label>
          <input value={f.name} disabled={dis} autoFocus onChange={(e) => set('name', e.target.value)} />{errors.name && <span className="msg">{errors.name}</span>}</div>
        <div className="field"><label>{t('stock.category')}</label><input value={f.category} disabled={dis} onChange={(e) => set('category', e.target.value)} /></div>
        <div className="field"><label>{t('stock.unit')}</label>
          <select value={f.unit} disabled={dis} onChange={(e) => set('unit', e.target.value)}>
            {constants.units.map((u) => <option key={u} value={u}>{t(`unit.${u}`)}</option>)}
          </select></div>
        <div className={`field ${errors.buy ? 'err' : ''}`}><label>{t('fields.buyPrice')} (₺)</label>
          <input value={f.buy} disabled={dis} inputMode="decimal" placeholder="0,00" onChange={(e) => set('buy', e.target.value)} />{errors.buy && <span className="msg">{errors.buy}</span>}</div>
        <div className={`field ${errors.sell ? 'err' : ''}`}><label>{t('fields.sellPrice')} (₺)</label>
          <input value={f.sell} disabled={dis} inputMode="decimal" placeholder="0,00" onChange={(e) => set('sell', e.target.value)} />{errors.sell && <span className="msg">{errors.sell}</span>}</div>
        <div className="field"><label>{t('fields.vat')}</label>
          <select value={f.vatBp} disabled={dis} onChange={(e) => set('vatBp', Number(e.target.value))}>
            {constants.vatRatesBp.map((v) => <option key={v} value={v}>{formatBp(v)}</option>)}
          </select></div>
        <div className={`field ${errors.min ? 'err' : ''}`}><label>{t('stock.minLevel')}</label>
          <input value={f.min} disabled={dis || !f.trackStock} inputMode="decimal" placeholder="0" onChange={(e) => set('min', e.target.value)} />{errors.min && <span className="msg">{errors.min}</span>}</div>
        <div className="field"><label>{t('fields.barcode')}</label><input value={f.barcode} disabled={dis} onChange={(e) => set('barcode', e.target.value)} /></div>
      </div>
      <label className="check"><input type="checkbox" checked={f.trackStock} disabled={dis} onChange={(e) => set('trackStock', e.target.checked)} />{t('fields.trackStock')}</label>
      <label className="check"><input type="checkbox" checked={f.active} disabled={dis} onChange={(e) => set('active', e.target.checked)} />{t('fields.active')}</label>

      {product && product.trackStock && (
        <>
          <h4 style={{ margin: '16px 0 8px' }}>{t('stock.byWarehouse')}</h4>
          {myLevels.length === 0 ? <div className="sub">{t('stock.noLevels')}</div> : (
            <table className="tbl"><tbody>
              {myLevels.map((l) => (
                <tr key={l.id}><td>{whName.get(l.warehouseId) ?? l.warehouseId}</td>
                  <td className="num">{formatMilli(l.qtyMilli)} {t(`unit.${product.unit}`)}</td></tr>
              ))}
            </tbody></table>
          )}
          <div className="sub" style={{ marginTop: 8 }}>{t('stock.quantity')} / {t('stock.unitCost')}: stok işlemleriyle değişir (fatura, sayım, transfer).</div>
        </>
      )}
    </Dialog>
  );
}
