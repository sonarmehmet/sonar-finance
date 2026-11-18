import { useMemo, useState } from 'react';
import { t } from '@/core/i18n';
import { useAuth } from '@/core/auth/AuthProvider';
import { useQuerySnapshot } from '@/core/hooks/useSnapshot';
import { formatDateTr } from '@/core/dates';
import { formatMilli, formatMinorTry } from '@/core/money';
import { stockMovementFromDoc, type Product, type Warehouse } from '@/data/models';
import { stockMovementsQuery } from '@/data/repositories';
import { EmptyState, ErrorState, LoadingState } from '@/components/ui';

const PAGE = 50;

export function MovementsTab({ products, warehouses }: { products: Product[]; warehouses: Warehouse[] }) {
  const { companyId } = useAuth();
  const [max, setMax] = useState(PAGE);
  const snap = useQuerySnapshot(() => (companyId ? stockMovementsQuery(companyId, max) : null), [companyId, max], stockMovementFromDoc);
  const pName = useMemo(() => new Map(products.map((p) => [p.id, p.name])), [products]);
  const wName = useMemo(() => new Map(warehouses.map((w) => [w.id, w.name])), [warehouses]);
  const rows = useMemo(() => [...snap.data].sort((a, b) => (b.date.localeCompare(a.date)) || (b.createdAtMs - a.createdAtMs)), [snap.data]);

  return (
    <div className="card table-wrap">
      {snap.loading ? <LoadingState /> : snap.error ? <ErrorState error={snap.error} /> : rows.length === 0 ? <EmptyState text={t('stock.noMovements')} /> : (
        <table className="tbl">
          <thead><tr><th>{t('invoiceColumns.date')}</th><th>{t('stock.name')}</th><th>{t('stock.warehouse')}</th><th>{t('invoiceColumns.type')}</th>
            <th className="num">{t('stock.quantity')}</th><th className="num">{t('stock.unitCost')}</th><th>{t('stock.note')}</th></tr></thead>
          <tbody>{rows.map((m) => (
            <tr key={m.id}><td>{formatDateTr(m.date)}</td><td>{pName.get(m.productId) ?? m.productId}</td><td>{wName.get(m.warehouseId) ?? m.warehouseId}</td>
              <td>{t(`stock.type.${m.type}`)}</td>
              <td className={`num ${m.deltaMilli >= 0 ? 'pos' : 'neg'}`}>{m.deltaMilli > 0 ? '+' : ''}{formatMilli(m.deltaMilli)}</td>
              <td className="num money">{formatMinorTry(m.unitCostMinor)}</td><td className="sub">{m.note}</td></tr>))}</tbody>
        </table>)}
      {snap.data.length >= max && !snap.loading && (
        <div style={{ textAlign: 'center', padding: 12 }}><button className="btn secondary sm" onClick={() => setMax(max + PAGE)}>{t('invoice.loadMore')}</button></div>)}
    </div>
  );
}
