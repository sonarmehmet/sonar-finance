import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Plus, Search } from 'lucide-react';
import { t } from '@/core/i18n';
import { useAuth } from '@/core/auth/AuthProvider';
import { useQuerySnapshot } from '@/core/hooks/useSnapshot';
import { formatDateTr } from '@/core/dates';
import { formatMinorTry, todayIso } from '@/core/money';
import { tokens } from '@/core/tokens';
import { invoiceFromDoc, displayStatus, remainingMinor, type Invoice } from '@/data/invoice';
import { invoicesQuery, type InvoiceTab } from '@/data/repositories';
import { Chip, EmptyState, ErrorState, LoadingState, Tabs } from '@/components/ui';

const PAGE = 25;
export const StatusChip = ({ inv }: { inv: Invoice }) => {
  const s = displayStatus(inv, todayIso());
  return <Chip color={tokens.status[s].color}>{t(`status.${s}`)}</Chip>;
};

export function InvoicesPage() {
  const { companyId, can } = useAuth();
  const navigate = useNavigate();
  const [tab, setTab] = useState<InvoiceTab>('all');
  const [max, setMax] = useState(PAGE);
  const [search, setSearch] = useState('');
  const snap = useQuerySnapshot(() => (companyId ? invoicesQuery(companyId, tab, max) : null), [companyId, tab, max], invoiceFromDoc);
  const rows = useMemo(() => {
    const q = search.trim().toLocaleLowerCase('tr-TR');
    return q ? snap.data.filter((i) => i.partyName.toLocaleLowerCase('tr-TR').includes(q) || (i.number ?? '').toLocaleLowerCase('tr-TR').includes(q)) : snap.data;
  }, [snap.data, search]);

  return (
    <div>
      <div className="page-head">
        <h2 style={{ margin: 0 }}>{t('menu.invoices')}</h2>
        <div className="spacer" />
        <label className="search"><Search size={16} /><input placeholder={t('common.search')} value={search} onChange={(e) => setSearch(e.target.value)} /></label>
        {can('invoice.write') && <button className="btn" onClick={() => navigate('/invoices/new')}><Plus size={16} />{t('invoice.newInvoice')}</button>}
      </div>
      <Tabs<InvoiceTab> value={tab} onChange={(k) => { setTab(k); setMax(PAGE); }}
        tabs={(['all', 'sales', 'purchase', 'returns', 'drafts'] as InvoiceTab[]).map((k) => ({ key: k, label: t(`invoiceTabs.${k}`) }))} />
      <div className="card table-wrap">
        {snap.loading ? <LoadingState /> : snap.error ? <ErrorState error={snap.error} /> : rows.length === 0 ? <EmptyState /> : (
          <table className="tbl">
            <thead><tr>
              <th>{t('invoiceColumns.number')}</th><th>{t('invoiceColumns.date')}</th><th>{t('invoiceColumns.party')}</th><th>{t('invoiceColumns.type')}</th>
              <th className="num">{t('invoiceColumns.total')}</th><th className="num">{t('invoiceColumns.remaining')}</th><th>{t('invoiceColumns.due')}</th><th>{t('invoiceColumns.status')}</th>
            </tr></thead>
            <tbody>{rows.map((i) => (
              <tr key={i.id} className="row" onClick={() => navigate(i.status === 'draft' ? `/invoices/${i.id}/edit` : `/invoices/${i.id}`)}>
                <td>{i.number ?? '—'}</td><td>{formatDateTr(i.issueDate)}</td><td>{i.partyName}</td><td>{t(`invoiceType.${i.type}`)}</td>
                <td className="num money">{formatMinorTry(i.totalMinor)}</td>
                <td className="num money">{i.status === 'issued' ? formatMinorTry(remainingMinor(i)) : '—'}</td>
                <td>{formatDateTr(i.dueDate)}</td><td><StatusChip inv={i} /></td>
              </tr>))}</tbody>
          </table>
        )}
        {snap.data.length >= max && !snap.loading && (
          <div style={{ textAlign: 'center', padding: 12 }}><button className="btn secondary sm" onClick={() => setMax(max + PAGE)}>{t('invoice.loadMore')}</button></div>
        )}
      </div>
    </div>
  );
}
