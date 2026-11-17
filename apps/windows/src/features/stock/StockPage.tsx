import { useMemo, useState } from 'react';
import { Plus, Search } from 'lucide-react';
import { t } from '@/core/i18n';
import { useAuth } from '@/core/auth/AuthProvider';
import { useQuerySnapshot } from '@/core/hooks/useSnapshot';
import { formatMilli, formatMinorTry, mulDiv } from '@/core/money';
import {
  isCritical, productFromDoc, stockLevelFromDoc, warehouseFromDoc, type Product, type Warehouse,
} from '@/data/models';
import { productsQuery, stockLevelsQuery, warehousesQuery } from '@/data/repositories';
import { Chip, EmptyState, ErrorState, Kpi, LoadingState, Tabs } from '@/components/ui';
import { ProductForm } from './ProductForm';
import { MovementsTab } from './MovementsTab';
import { StockActionDialog, type StockAction } from './StockActionDialog';
import { WarehouseForm } from './WarehouseForm';

type Tab = 'products' | 'warehouses' | 'movements';
type Filter = 'all' | 'critical' | 'passive';

export function StockPage() {
  const { companyId, can } = useAuth();
  const [tab, setTab] = useState<Tab>('products');
  const products = useQuerySnapshot(() => (companyId ? productsQuery(companyId) : null), [companyId], productFromDoc);
  const warehouses = useQuerySnapshot(() => (companyId ? warehousesQuery(companyId) : null), [companyId], warehouseFromDoc);
  const levels = useQuerySnapshot(() => (companyId ? stockLevelsQuery(companyId) : null), [companyId], stockLevelFromDoc);

  const stats = useMemo(() => {
    const active = products.data.filter((p) => p.active);
    return {
      count: active.length,
      value: active.reduce((s, p) => s + (p.trackStock ? mulDiv(p.totalQtyMilli, p.avgCostMinor, 1000) : 0), 0),
      critical: active.filter(isCritical).length,
    };
  }, [products.data]);

  return (
    <>
      <div className="kpis">
        <Kpi title={t('stock.totalProducts')} value={stats.count} />
        <Kpi title={t('stock.totalValue')} value={formatMinorTry(stats.value)} />
        <Kpi title={t('stock.criticalStock')} value={stats.critical} tone={stats.critical > 0 ? 'warn' : undefined} />
      </div>
      <Tabs<Tab> value={tab} onChange={setTab} tabs={[
        { key: 'products', label: t('stock.products') },
        { key: 'warehouses', label: t('stock.warehouses') },
        { key: 'movements', label: t('stock.movements') },
      ]} />
      {tab === 'products' && (
        <ProductsTab products={products.data} loading={products.loading} error={products.error}
          levels={levels.data} warehouses={warehouses.data} canWrite={can('stock.write')} />
      )}
      {tab === 'movements' && <MovementsTab products={products.data} warehouses={warehouses.data} />}
      {tab === 'warehouses' && (
        <WarehousesTab warehouses={warehouses.data} loading={warehouses.loading} error={warehouses.error}
          levelCounts={levels.data} canWrite={can('stock.write')} />
      )}
    </>
  );
}

function ProductsTab({ products, loading, error, levels, warehouses, canWrite }: {
  products: Product[]; loading: boolean; error: Error | null;
  levels: ReturnType<typeof stockLevelFromDoc>[]; warehouses: Warehouse[]; canWrite: boolean;
}) {
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState<Filter>('all');
  const [dialog, setDialog] = useState<{ product?: Product } | null>(null);
  const [action, setAction] = useState<StockAction | null>(null);
  const whName = useMemo(() => new Map(warehouses.map((w) => [w.id, w.name])), [warehouses]);
  const byProduct = useMemo(() => {
    const m = new Map<string, string>();
    for (const l of levels) {
      if (l.qtyMilli === 0) continue;
      const part = `${whName.get(l.warehouseId) ?? '?'} ${formatMilli(l.qtyMilli)}`;
      m.set(l.productId, m.has(l.productId) ? `${m.get(l.productId)} · ${part}` : part);
    }
    return m;
  }, [levels, whName]);

  const rows = useMemo(() => {
    const q = search.trim().toLocaleLowerCase('tr-TR');
    return products.filter((p) => {
      if (filter === 'critical' && !(p.active && isCritical(p))) return false;
      if (filter === 'passive' && p.active) return false;
      if (filter !== 'passive' && filter !== 'all' && !p.active) return false;
      return !q || p.name.toLocaleLowerCase('tr-TR').includes(q) || p.code.toLocaleLowerCase('tr-TR').includes(q) || p.barcode.includes(q);
    });
  }, [products, search, filter]);

  return (
    <div className="card" style={{ padding: 0 }}>
      <div className="filters">
        <label className="search"><Search size={16} />
          <input placeholder={t('common.search')} value={search} onChange={(e) => setSearch(e.target.value)} /></label>
        {(['all', 'critical', 'passive'] as Filter[]).map((k) => (
          <button key={k} className={`pill ${filter === k ? 'on' : ''}`} onClick={() => setFilter(k)}>
            {k === 'all' ? t('common.all') : k === 'critical' ? t('stock.criticalBadge') : t('common.passive')}
          </button>
        ))}
        <div className="spacer" />
        {canWrite && (['in', 'out', 'adjust', 'transfer'] as StockAction[]).map((a) => (
          <button key={a} className="btn secondary sm" onClick={() => setAction(a)}>{t(`stock.${a === 'in' ? 'stockIn' : a === 'out' ? 'stockOut' : a}`)}</button>))}
        {canWrite && <button className="btn sm" onClick={() => setDialog({})}><Plus size={14} />{t('stock.newProduct')}</button>}
      </div>
      {loading ? <LoadingState /> : error ? <ErrorState error={error} /> : rows.length === 0 ? <EmptyState /> : (
        <div className="table-wrap">
          <table className="tbl">
            <thead><tr>
              <th>{t('stock.code')}</th><th>{t('stock.name')}</th><th>{t('stock.category')}</th><th>{t('stock.unit')}</th>
              <th className="num">{t('stock.quantity')}</th><th className="num">{t('stock.unitCost')}</th><th className="num">{t('stock.value')}</th>
              <th>{t('stock.warehouse')}</th><th className="num">{t('stock.minLevel')}</th><th />
            </tr></thead>
            <tbody>
              {rows.map((p) => (
                <tr key={p.id} className="row" onClick={() => setDialog({ product: p })}>
                  <td>{p.code}</td><td>{p.name}</td><td>{p.category}</td><td>{t(`unit.${p.unit}`)}</td>
                  <td className="num">{p.trackStock ? formatMilli(p.totalQtyMilli) : '—'}</td>
                  <td className="num">{p.trackStock ? formatMinorTry(p.avgCostMinor) : '—'}</td>
                  <td className="num">{p.trackStock ? formatMinorTry(mulDiv(p.totalQtyMilli, p.avgCostMinor, 1000)) : '—'}</td>
                  <td className="sub">{p.trackStock ? (byProduct.get(p.id) ?? '') : t('stock.trackingOff')}</td>
                  <td className="num">{p.trackStock && p.minStockMilli ? formatMilli(p.minStockMilli) : ''}</td>
                  <td>{!p.active ? <Chip color="var(--c-neutral)">{t('common.passive')}</Chip> : isCritical(p) ? <Chip color="var(--c-warning)">{t('stock.criticalBadge')}</Chip> : null}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {action && <StockActionDialog action={action} products={products} warehouses={warehouses} levels={levels} onClose={() => setAction(null)} />}
      {dialog && <ProductForm product={dialog.product} products={products} levels={levels} warehouses={warehouses}
        readOnly={!canWrite} onClose={() => setDialog(null)} />}
    </div>
  );
}

function WarehousesTab({ warehouses, loading, error, levelCounts, canWrite }: {
  warehouses: Warehouse[]; loading: boolean; error: Error | null;
  levelCounts: ReturnType<typeof stockLevelFromDoc>[]; canWrite: boolean;
}) {
  const [dialog, setDialog] = useState<{ warehouse?: Warehouse } | null>(null);
  const itemCount = useMemo(() => {
    const m = new Map<string, number>();
    for (const l of levelCounts) if (l.qtyMilli !== 0) m.set(l.warehouseId, (m.get(l.warehouseId) ?? 0) + 1);
    return m;
  }, [levelCounts]);

  return (
    <div className="card" style={{ padding: 0 }}>
      <div className="filters">
        <div className="spacer" />
        {canWrite && <button className="btn sm" onClick={() => setDialog({})}><Plus size={14} />{t('stock.newWarehouse')}</button>}
      </div>
      {loading ? <LoadingState /> : error ? <ErrorState error={error} /> : warehouses.length === 0 ? <EmptyState /> : (
        <table className="tbl">
          <thead><tr><th>{t('stock.name')}</th><th>{t('fields.location')}</th><th className="num">{t('stock.products')}</th><th /></tr></thead>
          <tbody>
            {warehouses.map((w) => (
              <tr key={w.id} className="row" onClick={() => canWrite && setDialog({ warehouse: w })}>
                <td>{w.name}</td><td>{w.location}</td><td className="num">{itemCount.get(w.id) ?? 0}</td>
                <td>
                  {w.isDefault && <Chip color="var(--c-accent)">{t('fields.isDefault')}</Chip>}{' '}
                  {!w.active && <Chip color="var(--c-neutral)">{t('common.passive')}</Chip>}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
      {dialog && <WarehouseForm warehouse={dialog.warehouse} all={warehouses} onClose={() => setDialog(null)} />}
    </div>
  );
}
