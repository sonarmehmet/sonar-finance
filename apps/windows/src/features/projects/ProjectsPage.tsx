import { useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { Pencil, Plus } from 'lucide-react';
import { t } from '@/core/i18n';
import { useAuth } from '@/core/auth/AuthProvider';
import { useQuerySnapshot } from '@/core/hooks/useSnapshot';
import { formatMinor, formatMinorTry, parseMinor } from '@/core/money';
import constants from '@shared/constants.json';
import { invoiceFromDoc } from '@/data/invoice';
import { partyFromDoc } from '@/data/models';
import { projectFromDoc, projectStatsFromDoc, type Project, type ProjectStats } from '@/data/projects';
import { partiesQuery, projectInvoicesQuery, projectRepo, projectsQuery, projectStatsQuery } from '@/data/repositories';
import { txErrorMessage } from '@/services/txErrors';
import { Chip, EmptyState, ErrorState, Kpi, LoadingState } from '@/components/ui';
import { Dialog } from '@/components/Dialog';
import { useToast } from '@/components/Toast';

const ZERO: ProjectStats = { id: '', revenueMinor: 0, costMinor: 0, collectedMinor: 0, paidOutMinor: 0, byDiscipline: {} };

export function ProjectsPage() {
  const { companyId, can } = useAuth();
  const { id } = useParams();
  const navigate = useNavigate();
  const projects = useQuerySnapshot(() => (companyId ? projectsQuery(companyId) : null), [companyId], projectFromDoc);
  const stats = useQuerySnapshot(() => (companyId ? projectStatsQuery(companyId) : null), [companyId], projectStatsFromDoc);
  const parties = useQuerySnapshot(() => (companyId ? partiesQuery(companyId) : null), [companyId], partyFromDoc);
  const [form, setForm] = useState<{ project?: Project } | null>(null);
  const sMap = useMemo(() => new Map(stats.data.map((s) => [s.id, s])), [stats.data]);
  const selected = projects.data.find((p) => p.id === id) ?? null;
  const canWrite = can('project.write');

  return (
    <div className="split">
      <div className="card list">
        <div className="filters"><div className="spacer" />{canWrite && <button className="btn sm" onClick={() => setForm({})}><Plus size={14} />{t('project.new')}</button>}</div>
        {projects.loading ? <LoadingState /> : projects.error ? <ErrorState error={projects.error} /> : projects.data.length === 0 ? <EmptyState /> : projects.data.map((p) => (
          <div key={p.id} className={`list-item ${p.id === id ? 'sel' : ''}`} onClick={() => navigate(`/projects/${p.id}`)}>
            <div className="grow"><div className="name">{p.name}</div><div className="sub">{p.location}</div></div>
            <Chip color={p.status === 'active' ? 'var(--c-positive)' : 'var(--c-neutral)'}>{t(`project.status.${p.status}`)}</Chip>
          </div>))}
      </div>
      <div className="card detail">
        {selected ? <ProjectDetail project={selected} stats={sMap.get(selected.id) ?? ZERO} partyName={parties.data.find((x) => x.id === selected.partyId)?.name ?? ''} canWrite={canWrite} onEdit={() => setForm({ project: selected })} />
          : <EmptyState text={t('project.select')} />}
      </div>
      {form && <ProjectForm project={form.project} parties={parties.data} onClose={() => setForm(null)} onSaved={(pid) => navigate(`/projects/${pid}`)} />}
    </div>
  );
}

function ProjectDetail({ project: p, stats: s, partyName, canWrite, onEdit }: { project: Project; stats: ProjectStats; partyName: string; canWrite: boolean; onEdit(): void }) {
  const { companyId } = useAuth();
  const invs = useQuerySnapshot(() => (companyId ? projectInvoicesQuery(companyId, p.id) : null), [companyId, p.id], invoiceFromDoc);
  const budgetTotal = Object.values(p.budgets).reduce((a, b) => a + b, 0);
  const estProfit = p.contractMinor - budgetTotal;
  const actualProfit = s.revenueMinor - s.costMinor;
  const margin = s.revenueMinor > 0 ? `%${((actualProfit / s.revenueMinor) * 100).toFixed(1).replace('.', ',')}` : '—';
  const issued = invs.data.filter((i) => i.status === 'issued');
  const recv = issued.filter((i) => i.type === 'sales').reduce((a, i) => a + i.totalMinor, 0) - issued.filter((i) => i.type === 'sales_return').reduce((a, i) => a + i.totalMinor, 0) - s.collectedMinor;
  const pay = issued.filter((i) => i.type === 'purchase').reduce((a, i) => a + i.totalMinor, 0) - issued.filter((i) => i.type === 'purchase_return').reduce((a, i) => a + i.totalMinor, 0) - s.paidOutMinor;
  const disciplines = [...new Set([...Object.keys(p.budgets), ...Object.keys(s.byDiscipline)])];

  return (
    <>
      <div className="page-head"><div style={{ flex: 1 }}><h2 style={{ margin: 0 }}>{p.name}</h2><div className="sub">{partyName}{p.location && ` · ${p.location}`}</div></div>
        {canWrite && <button className="btn secondary" onClick={onEdit}><Pencil size={14} />{t('common.edit')}</button>}</div>
      <div className="kpis" style={{ marginBottom: 'var(--s-lg)' }}>
        <Kpi title={t('project.contract')} value={formatMinorTry(p.contractMinor)} />
        <Kpi title={t('project.revenue')} value={formatMinorTry(s.revenueMinor)} />
        <Kpi title={t('project.cost')} value={formatMinorTry(s.costMinor)} />
        <Kpi title={t('project.collected')} value={formatMinorTry(s.collectedMinor)} />
        <Kpi title={t('project.estProfit')} value={formatMinorTry(estProfit)} tone={estProfit < 0 ? 'neg' : undefined} />
        <Kpi title={t('project.actualProfit')} value={formatMinorTry(actualProfit)} tone={actualProfit < 0 ? 'neg' : 'pos'} />
        <Kpi title={t('project.margin')} value={margin} />
        <Kpi title={t('project.remainingReceivable')} value={formatMinorTry(recv)} />
        <Kpi title={t('project.remainingPayable')} value={formatMinorTry(pay)} />
      </div>
      <h3>{t('project.disciplines')}</h3>
      {disciplines.length === 0 ? <div className="sub">{t('common.empty')}</div> : (
        <table className="tbl"><thead><tr><th>{t('expense.discipline')}</th><th className="num">{t('project.budget')}</th><th className="num">{t('project.actual')}</th><th className="num">{t('project.remainingBudget')}</th></tr></thead>
          <tbody>{disciplines.map((d) => { const b = p.budgets[d] ?? 0, a = s.byDiscipline[d] ?? 0, rem = b - a;
            return <tr key={d}><td>{t(`disciplines.${d}`)}</td><td className="num money">{formatMinorTry(b)}</td><td className="num money">{formatMinorTry(a)}</td>
              <td className={`num money ${rem < 0 ? 'neg' : ''}`}>{formatMinorTry(rem)}</td></tr>; })}</tbody></table>)}
    </>
  );
}

function ProjectForm({ project, parties, onClose, onSaved }: { project?: Project; parties: { id: string; name: string; active: boolean }[]; onClose(): void; onSaved(id: string): void }) {
  const { companyId } = useAuth();
  const toast = useToast();
  const [f, setF] = useState({
    name: project?.name ?? '', partyId: project?.partyId ?? '', location: project?.location ?? '', startDate: project?.startDate ?? '', endDate: project?.endDate ?? '',
    contract: project ? formatMinor(project.contractMinor) : '', status: project?.status ?? 'active', notes: project?.notes ?? '',
  });
  const [budgets, setBudgets] = useState<Record<string, string>>(Object.fromEntries(Object.entries(project?.budgets ?? {}).map(([k, v]) => [k, formatMinor(v)])));
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const set = (k: keyof typeof f, v: string) => setF((x) => ({ ...x, [k]: v }));

  const save = async () => {
    if (!f.name.trim()) { setError(t('validation.required')); return; }
    const contract = f.contract.trim() === '' ? 0 : parseMinor(f.contract);
    if (contract === null) { setError(t('validation.invalidAmount')); return; }
    const bm: Record<string, number> = {};
    for (const [k, v] of Object.entries(budgets) as [string, string][]) { if (v.trim() === '') continue; const n = parseMinor(v); if (n === null) { setError(t('validation.invalidAmount')); return; } if (n > 0) bm[k] = n; }
    setBusy(true); setError(null);
    try {
      const r = await projectRepo.save(companyId!, project?.id ?? null, {
        name: f.name.trim(), partyId: f.partyId, location: f.location.trim(), startDate: f.startDate, endDate: f.endDate, contractMinor: contract,
        status: f.status, budgets: bm, notes: f.notes.trim(),
      });
      toast('success', r.synced ? t('messages.saved') : t('messages.queued')); onSaved(r.id); onClose();
    } catch (e) { setError(txErrorMessage(e)); } finally { setBusy(false); }
  };
  return (
    <Dialog title={project ? t('project.edit') : t('project.new')} onClose={onClose} width={640}
      footer={<><button className="btn secondary" onClick={onClose}>{t('common.cancel')}</button><button className="btn" disabled={busy} onClick={save}>{t('common.save')}</button></>}>
      {error && <div className="error" role="alert">{error}</div>}
      <div className="grid2">
        <div className="field"><label>{t('stock.name')}</label><input value={f.name} onChange={(e) => set('name', e.target.value)} /></div>
        <div className="field"><label>{t('invoice.party')}</label><select value={f.partyId} onChange={(e) => set('partyId', e.target.value)}><option value="" />{parties.filter((p) => p.active).map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}</select></div>
        <div className="field"><label>{t('fields.location')}</label><input value={f.location} onChange={(e) => set('location', e.target.value)} /></div>
        <div className="field"><label>{t('project.contract')}</label><input value={f.contract} onChange={(e) => set('contract', e.target.value)} inputMode="decimal" /></div>
        <div className="field"><label>{t('project.start')}</label><input type="date" value={f.startDate} onChange={(e) => set('startDate', e.target.value)} /></div>
        <div className="field"><label>{t('project.end')}</label><input type="date" value={f.endDate} onChange={(e) => set('endDate', e.target.value)} /></div>
        <div className="field"><label>{t('invoice.status')}</label><select value={f.status} onChange={(e) => set('status', e.target.value)}>{['active', 'paused', 'done'].map((s) => <option key={s} value={s}>{t(`project.status.${s}`)}</option>)}</select></div>
      </div>
      <h4>{t('project.budgets')}</h4>
      <div className="grid2">{constants.disciplines.map((d) => (
        <div className="field" key={d}><label>{t(`disciplines.${d}`)}</label><input value={budgets[d] ?? ''} onChange={(e) => setBudgets({ ...budgets, [d]: e.target.value })} inputMode="decimal" /></div>))}</div>
      <div className="field"><label>{t('fields.notes')}</label><textarea rows={2} value={f.notes} onChange={(e) => set('notes', e.target.value)} /></div>
    </Dialog>
  );
}
