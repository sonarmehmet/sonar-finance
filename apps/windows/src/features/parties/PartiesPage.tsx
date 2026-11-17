import { useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { Pencil, Plus, Search } from 'lucide-react';
import { t } from '@/core/i18n';
import { useAuth } from '@/core/auth/AuthProvider';
import { useQuerySnapshot } from '@/core/hooks/useSnapshot';
import { formatMinorTry } from '@/core/money';
import { ledgerFromDoc, partyFromDoc, type LedgerEntry, type Party } from '@/data/models';
import { ledgerQuery, partiesQuery } from '@/data/repositories';
import { Balance, Chip, EmptyState, ErrorState, LoadingState, Tabs } from '@/components/ui';
import { PartyForm } from './PartyForm';

type KindFilter = 'all' | 'customer' | 'supplier';
type DetailTab = 'overview' | 'movements' | 'invoices' | 'collections' | 'payments';

export function PartiesPage() {
  const { companyId, can } = useAuth();
  const { id } = useParams();
  const navigate = useNavigate();
  const parties = useQuerySnapshot(() => (companyId ? partiesQuery(companyId) : null), [companyId], partyFromDoc);
  const [search, setSearch] = useState('');
  const [kind, setKind] = useState<KindFilter>('all');
  const [form, setForm] = useState<{ party?: Party } | null>(null);
  const canWrite = can('party.write');

  const filtered = useMemo(() => {
    const q = search.trim().toLocaleLowerCase('tr-TR');
    return parties.data.filter((p) =>
      (kind === 'all' || p.kinds.includes(kind)) && (!q || p.name.toLocaleLowerCase('tr-TR').includes(q) || p.taxNo.includes(q) || p.phone.includes(q)));
  }, [parties.data, search, kind]);
  const selected = parties.data.find((p) => p.id === id) ?? null;

  return (
    <div className="split">
      <div className="card list">
        <div className="filters">
          <label className="search" style={{ width: '100%' }}><Search size={16} />
            <input placeholder={t('common.search')} value={search} onChange={(e) => setSearch(e.target.value)} />
          </label>
          {(['all', 'customer', 'supplier'] as KindFilter[]).map((k) => (
            <button key={k} className={`pill ${kind === k ? 'on' : ''}`} onClick={() => setKind(k)}>
              {k === 'all' ? t('common.all') : t(`party.${k}`)}
            </button>
          ))}
          <div className="spacer" />
          {canWrite && <button className="btn sm" onClick={() => setForm({})}><Plus size={14} />{t('party.newParty')}</button>}
        </div>
        {parties.loading ? <LoadingState /> : parties.error ? <ErrorState error={parties.error} /> :
          filtered.length === 0 ? <EmptyState /> : filtered.map((p) => (
            <div key={p.id} className={`list-item ${p.id === id ? 'sel' : ''}`} onClick={() => navigate(`/parties/${p.id}`)}>
              <div className="grow">
                <div className="name">{p.name}{!p.active && <> <Chip color="var(--c-neutral)">{t('common.passive')}</Chip></>}</div>
                <div className="sub">{p.kinds.length === 2 ? t('fields.kindBoth') : p.kinds.map((k) => t(`party.${k}`)).join(', ')}{p.phone && ` · ${p.phone}`}</div>
              </div>
              <Balance minor={p.balanceMinor} />
            </div>
          ))}
      </div>

      <div className="card detail">
        {selected ? <PartyDetail party={selected} canWrite={canWrite} onEdit={() => setForm({ party: selected })} /> : <EmptyState text={t('party.statement')} />}
      </div>

      {form && <PartyForm party={form.party} onClose={() => setForm(null)} onSaved={(pid) => navigate(`/parties/${pid}`)} />}
    </div>
  );
}

function PartyDetail({ party, canWrite, onEdit }: { party: Party; canWrite: boolean; onEdit(): void }) {
  const [tab, setTab] = useState<DetailTab>('overview');
  const label = party.balanceMinor > 0 ? t('party.balanceReceivable') : party.balanceMinor < 0 ? t('party.balanceDebt') : t('party.balanceZero');
  return (
    <>
      <div className="page-head">
        <div style={{ flex: 1 }}>
          <h2 style={{ margin: 0 }}>{party.name}</h2>
          <div className="sub">{party.kinds.length === 2 ? t('fields.kindBoth') : party.kinds.map((k) => t(`party.${k}`)).join(', ')}</div>
        </div>
        <div style={{ textAlign: 'right' }}>
          <div className="big-balance"><Balance minor={party.balanceMinor} /></div>
          <div className="sub">{label}</div>
        </div>
        {canWrite && <button className="btn secondary" onClick={onEdit}><Pencil size={14} />{t('common.edit')}</button>}
      </div>
      <Tabs<DetailTab> value={tab} onChange={setTab} tabs={[
        { key: 'overview', label: t('party.tabs.overview') },
        { key: 'movements', label: t('party.tabs.movements') },
        { key: 'invoices', label: t('party.tabs.invoices'), disabled: true },
        { key: 'collections', label: t('party.tabs.collections'), disabled: true },
        { key: 'payments', label: t('party.tabs.payments'), disabled: true },
      ]} />
      {tab === 'overview' && (
        <dl className="kv">
          <dt>{t('fields.taxOffice')}</dt><dd>{party.taxOffice || '—'}</dd>
          <dt>{t('fields.taxNo')}</dt><dd>{party.taxNo || '—'}</dd>
          <dt>{t('party.phone')}</dt><dd>{party.phone || '—'}</dd>
          <dt>{t('fields.email')}</dt><dd>{party.email || '—'}</dd>
          <dt>{t('fields.address')}</dt><dd>{party.address || '—'}</dd>
          <dt>{t('fields.notes')}</dt><dd>{party.notes || '—'}</dd>
        </dl>
      )}
      {tab === 'movements' && <PartyLedger party={party} />}
    </>
  );
}

/** docs/08 §5: Borç = delta>0 (cari bize borçlandı), Alacak = |delta| için delta<0; bakiye kümülatif. */
function PartyLedger({ party }: { party: Party }) {
  const { companyId } = useAuth();
  const q = useQuerySnapshot(() => (companyId ? ledgerQuery(companyId, party.id) : null), [companyId, party.id], ledgerFromDoc);

  const rows = useMemo(() => {
    const sorted: LedgerEntry[] = [...q.data].sort((a, b) => a.date.localeCompare(b.date) || a.createdAtMs - b.createdAtMs || a.txId.localeCompare(b.txId));
    const total = sorted.reduce((s, e) => s + e.deltaMinor, 0);
    let running = party.balanceMinor - total; // açılış
    return sorted.map((e) => { running += e.deltaMinor; return { e, balance: running }; });
  }, [q.data, party.balanceMinor]);

  if (q.loading) return <LoadingState />;
  if (q.error) return <ErrorState error={q.error} />;
  if (rows.length === 0) return <EmptyState text={t('party.noMovements')} />;
  return (
    <div className="table-wrap">
      <table className="tbl">
        <thead><tr>
          <th>{t('invoiceColumns.date')}</th><th>{t('invoiceForm.description')}</th>
          <th className="num">{t('party.debt')}</th><th className="num">{t('party.receivable')}</th><th className="num">{t('party.net')}</th>
        </tr></thead>
        <tbody>
          {rows.map(({ e, balance }) => (
            <tr key={e.id}>
              <td>{e.date}</td>
              <td>{e.description || t(`ledger.${e.refType}`)}</td>
              <td className="num">{e.deltaMinor > 0 ? formatMinorTry(e.deltaMinor) : ''}</td>
              <td className="num">{e.deltaMinor < 0 ? formatMinorTry(-e.deltaMinor) : ''}</td>
              <td className="num"><Balance minor={balance} /></td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
