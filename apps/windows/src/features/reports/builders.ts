/** Rapor üreticiler (docs/08 §6). Veriyi tek seferlik okur (dinleyici yok: Spark kotası). */
import { collection, doc, getDoc, getDocs, orderBy, query, where, limit, type DocumentData } from 'firebase/firestore';
import { db } from '@/core/firebase';
import { t } from '@/core/i18n';
import { formatMilli, mulDiv } from '@/core/money';
import { formatDateTr } from '@/core/dates';
import { invoiceFromDoc } from '@/data/invoice';
import { accountFromDoc, paymentFromDoc, accountMovementFromDoc } from '@/data/finance';
import { partyFromDoc, productFromDoc, stockLevelFromDoc, warehouseFromDoc } from '@/data/models';
import { expenseFromDoc, projectFromDoc, projectStatsFromDoc } from '@/data/projects';
import type { Column, ReportData } from './export';

export type ReportKey = 'monthly' | 'yearly' | 'cash' | 'bank' | 'debtCredit' | 'vat' | 'projectCost' | 'projectProfit' | 'stockValue' | 'collections' | 'payments';
export const REPORT_KEYS: ReportKey[] = ['monthly', 'yearly', 'cash', 'bank', 'debtCredit', 'vat', 'projectCost', 'projectProfit', 'stockValue', 'collections', 'payments'];
export const NEEDS_RANGE: ReportKey[] = ['cash', 'bank', 'vat', 'collections', 'payments'];

export interface Opts { from: string; to: string; month: string; year: string; includeCancelled: boolean }

const toMap = <T extends { id: string }>(a: T[]): Map<string, T> => new Map(a.map((x): [string, T] => [x.id, x]));
const col = (cid: string, name: string) => collection(db, 'companies', cid, name);
const int = (v: unknown): number => (typeof v === 'number' && Number.isFinite(v) ? Math.trunc(v) : 0);
const pct = (a: number, b: number): string => (b === 0 ? '—' : `%${((a / b) * 100).toFixed(1).replace('.', ',')}`);
const mc = (key: string, label: string): Column => ({ key, label, money: true });
const rangeText = (o: Opts) => `${formatDateTr(o.from)} – ${formatDateTr(o.to)}`;

async function statsMonths(cid: string): Promise<Record<string, Record<string, number>>> {
  const s = (await getDoc(doc(db, 'companies', cid, 'stats', 'summary'))).data() as DocumentData | undefined;
  return (s?.months ?? {}) as Record<string, Record<string, number>>;
}

export async function build(key: ReportKey, cid: string, o: Opts): Promise<ReportData> {
  const title = t(`reports.${key}`);
  switch (key) {
    case 'monthly': {
      const months = await statsMonths(cid);
      const [y, m] = o.month.split('-').map(Number);
      const prevKey = m === 1 ? `${y - 1}-12` : `${y}-${String(m - 1).padStart(2, '0')}`;
      const row = (k: string) => ({ month: k, income: int(months[k]?.incomeMinor), expense: int(months[k]?.expenseMinor), net: int(months[k]?.incomeMinor) - int(months[k]?.expenseMinor) });
      const rows = [row(prevKey), row(o.month)];
      return { title, range: o.month, columns: [{ key: 'month', label: t('reports.month') }, mc('income', t('dashboard.monthIncome')), mc('expense', t('dashboard.monthExpense')), mc('net', t('expense.net'))], rows,
        summary: [[t('dashboard.monthIncome'), rows[1].income, true], [t('dashboard.monthExpense'), rows[1].expense, true], [t('expense.net'), rows[1].net, true]] };
    }
    case 'yearly': {
      const months = await statsMonths(cid);
      const rows = Array.from({ length: 12 }, (_, i) => { const k = `${o.year}-${String(i + 1).padStart(2, '0')}`; const inc = int(months[k]?.incomeMinor), exp = int(months[k]?.expenseMinor); return { month: k, income: inc, expense: exp, net: inc - exp }; });
      const tot = rows.reduce((a, r) => ({ income: a.income + r.income, expense: a.expense + r.expense, net: a.net + r.net }), { income: 0, expense: 0, net: 0 });
      return { title, range: o.year, columns: [{ key: 'month', label: t('reports.month') }, mc('income', t('dashboard.monthIncome')), mc('expense', t('dashboard.monthExpense')), mc('net', t('expense.net'))], rows: [...rows, { month: t('reports.total'), ...tot }],
        summary: [[t('dashboard.monthIncome'), tot.income, true], [t('dashboard.monthExpense'), tot.expense, true], [t('expense.net'), tot.net, true]] };
    }
    case 'cash': case 'bank': {
      const accs = (await getDocs(query(col(cid, 'accounts'), orderBy('name')))).docs.map(accountFromDoc).filter((a) => a.type === key);
      const rows: Record<string, string | number>[] = [];
      let opening = 0, closing = 0, inSum = 0, outSum = 0;
      for (const a of accs) {
        const all = (await getDocs(query(col(cid, 'account_movements'), where('accountId', '==', a.id), orderBy('date', 'asc'), limit(5000)))).docs.map(accountMovementFromDoc);
        const before = all.filter((m) => m.date < o.from).reduce((s, m) => s + m.deltaMinor, 0);
        const inRange = all.filter((m) => m.date >= o.from && m.date <= o.to).sort((x, y) => x.date.localeCompare(y.date) || x.createdAtMs - y.createdAtMs);
        let bal = before; opening += before;
        for (const m of inRange) { bal += m.deltaMinor; rows.push({ account: a.name, date: formatDateTr(m.date), desc: t(`ledger.${m.refType}`) === `ledger.${m.refType}` ? m.refType : t(`ledger.${m.refType}`), in: m.deltaMinor > 0 ? m.deltaMinor : 0, out: m.deltaMinor < 0 ? -m.deltaMinor : 0, balance: bal }); if (m.deltaMinor > 0) inSum += m.deltaMinor; else outSum -= m.deltaMinor; }
        closing += bal;
      }
      return { title, range: rangeText(o), columns: [{ key: 'account', label: t('cashBank.account') }, { key: 'date', label: t('payment.date') }, { key: 'desc', label: t('invoiceForm.description') }, mc('in', t('reports.in')), mc('out', t('reports.out')), mc('balance', t('reports.balance'))], rows,
        summary: [[t('reports.opening'), opening, true], [t('reports.in'), inSum, true], [t('reports.out'), outSum, true], [t('reports.closing'), closing, true]] };
    }
    case 'debtCredit': {
      const parties = (await getDocs(query(col(cid, 'parties'), orderBy('name'), limit(2000)))).docs.map(partyFromDoc).filter((p) => p.active);
      const rows = parties.map((p) => ({ name: p.name, kind: p.kinds.map((k) => t(`party.${k}`)).join(', '), receivable: Math.max(p.balanceMinor, 0), payable: Math.max(-p.balanceMinor, 0), net: p.balanceMinor }));
      const recv = rows.reduce((s, r) => s + r.receivable, 0), pay = rows.reduce((s, r) => s + r.payable, 0);
      return { title, range: formatDateTr(o.to), columns: [{ key: 'name', label: t('party.name') }, { key: 'kind', label: t('party.kind') }, mc('receivable', t('party.receivable')), mc('payable', t('party.debt')), mc('net', t('party.net'))], rows,
        summary: [[t('party.receivable'), recv, true], [t('party.debt'), pay, true], [t('party.net'), recv - pay, true]] };
    }
    case 'vat': {
      const inv = (await getDocs(query(col(cid, 'invoices'), where('issueDate', '>=', o.from), where('issueDate', '<=', o.to), orderBy('issueDate', 'asc'), limit(5000)))).docs.map(invoiceFromDoc).filter((i) => i.status === 'issued' || (o.includeCancelled && i.status === 'cancelled'));
      const exp = (await getDocs(query(col(cid, 'expenses'), where('date', '>=', o.from), where('date', '<=', o.to), orderBy('date', 'asc'), limit(5000)))).docs.map(expenseFromDoc).filter((e) => e.status === 'active');
      const by = new Map<number, { calc: number; deduct: number }>();
      const add = (bp: number, calc: number, deduct: number) => { const c = by.get(bp) ?? { calc: 0, deduct: 0 }; c.calc += calc; c.deduct += deduct; by.set(bp, c); };
      let calc = 0, ded = 0;
      for (const i of inv.filter((x) => x.status === 'issued')) for (const l of i.lines) {
        if (i.type === 'sales') { add(l.vatBp, l.vatMinor, 0); calc += l.vatMinor; }
        else if (i.type === 'sales_return') { add(l.vatBp, -l.vatMinor, 0); calc -= l.vatMinor; }
        else if (i.type === 'purchase') { add(l.vatBp, 0, l.vatMinor); ded += l.vatMinor; }
        else { add(l.vatBp, 0, -l.vatMinor); ded -= l.vatMinor; }
      }
      const expVat = exp.reduce((s, e) => s + e.vatMinor, 0); ded += expVat; if (expVat) add(-1, 0, expVat);
      const rows = [...by.entries()].sort((a, b) => a[0] - b[0]).map(([bp, v]) => ({ rate: bp < 0 ? t('reports.expenses') : `%${bp / 100}`, calc: v.calc, deduct: v.deduct, net: v.calc - v.deduct }));
      return { title, range: rangeText(o), columns: [{ key: 'rate', label: t('invoiceForm.vat') }, mc('calc', t('reports.calcVat')), mc('deduct', t('reports.deductVat')), mc('net', t('reports.payableVat'))], rows,
        summary: [[t('reports.calcVat'), calc, true], [t('reports.deductVat'), ded, true], [t('reports.payableVat'), calc - ded, true]] };
    }
    case 'projectCost': {
      const projects = (await getDocs(query(col(cid, 'projects'), orderBy('name')))).docs.map(projectFromDoc);
      const stats = toMap((await getDocs(col(cid, 'project_stats'))).docs.map(projectStatsFromDoc));
      const rows: Record<string, string | number>[] = []; let b = 0, a = 0;
      for (const p of projects) {
        const s = stats.get(p.id);
        for (const d of new Set([...Object.keys(p.budgets), ...Object.keys(s?.byDiscipline ?? {})])) {
          const bud = p.budgets[d] ?? 0, act = s?.byDiscipline[d] ?? 0; b += bud; a += act;
          rows.push({ project: p.name, discipline: t(`disciplines.${d}`), budget: bud, actual: act, remaining: bud - act, pct: pct(act, bud) });
        }
      }
      return { title, range: formatDateTr(o.to), columns: [{ key: 'project', label: t('menu.projects') }, { key: 'discipline', label: t('expense.discipline') }, mc('budget', t('project.budget')), mc('actual', t('project.actual')), mc('remaining', t('project.remainingBudget')), { key: 'pct', label: '%', num: true }], rows,
        summary: [[t('project.budget'), b, true], [t('project.actual'), a, true], [t('project.remainingBudget'), b - a, true]] };
    }
    case 'projectProfit': {
      const projects = (await getDocs(query(col(cid, 'projects'), orderBy('name')))).docs.map(projectFromDoc);
      const stats = toMap((await getDocs(col(cid, 'project_stats'))).docs.map(projectStatsFromDoc));
      const rows = projects.map((p) => { const s = stats.get(p.id); const rev = s?.revenueMinor ?? 0, cost = s?.costMinor ?? 0; const bud = Object.values(p.budgets).reduce((x, y) => x + y, 0);
        return { project: p.name, contract: p.contractMinor, revenue: rev, cost, est: p.contractMinor - bud, actual: rev - cost, margin: pct(rev - cost, rev) }; });
      const sum = (k: 'revenue' | 'cost' | 'actual') => rows.reduce((s, r) => s + r[k], 0);
      return { title, range: formatDateTr(o.to), columns: [{ key: 'project', label: t('menu.projects') }, mc('contract', t('project.contract')), mc('revenue', t('project.revenue')), mc('cost', t('project.cost')), mc('est', t('project.estProfit')), mc('actual', t('project.actualProfit')), { key: 'margin', label: t('project.margin'), num: true }], rows,
        summary: [[t('project.revenue'), sum('revenue'), true], [t('project.cost'), sum('cost'), true], [t('project.actualProfit'), sum('actual'), true]] };
    }
    case 'stockValue': {
      const products = toMap((await getDocs(query(col(cid, 'products'), limit(3000)))).docs.map(productFromDoc));
      const whs = new Map((await getDocs(col(cid, 'warehouses'))).docs.map(warehouseFromDoc).map((w): [string, string] => [w.id, w.name]));
      const levels = (await getDocs(query(col(cid, 'stock_levels'), limit(10000)))).docs.map(stockLevelFromDoc).filter((l) => l.qtyMilli !== 0);
      let total = 0;
      const rows = levels.map((l) => { const p = products.get(l.productId); const v = p ? mulDiv(l.qtyMilli, p.avgCostMinor, 1000) : 0; total += v;
        return { product: p?.name ?? l.productId, warehouse: whs.get(l.warehouseId) ?? '', qty: formatMilli(l.qtyMilli), avg: p?.avgCostMinor ?? 0, value: v }; }).sort((a, b) => a.product.localeCompare(b.product, 'tr'));
      return { title, range: formatDateTr(o.to), columns: [{ key: 'product', label: t('stock.name') }, { key: 'warehouse', label: t('stock.warehouse') }, { key: 'qty', label: t('stock.quantity'), num: true }, mc('avg', t('stock.unitCost')), mc('value', t('stock.value'))], rows,
        summary: [[t('stock.totalValue'), total, true]] };
    }
    case 'collections': case 'payments': {
      const dir = key === 'collections' ? 'in' : 'out';
      const pays = (await getDocs(query(col(cid, 'payments'), where('date', '>=', o.from), where('date', '<=', o.to), orderBy('date', 'asc'), limit(5000)))).docs.map(paymentFromDoc).filter((p) => p.direction === dir && (p.status === 'active' || o.includeCancelled));
      const names = new Map((await getDocs(query(col(cid, 'parties'), limit(3000)))).docs.map(partyFromDoc).map((p): [string, string] => [p.id, p.name]));
      const accs = new Map((await getDocs(col(cid, 'accounts'))).docs.map(accountFromDoc).map((a): [string, string] => [a.id, a.name]));
      const invNo = new Map((await getDocs(query(col(cid, 'invoices'), orderBy('issueDate', 'desc'), limit(3000)))).docs.map(invoiceFromDoc).map((i): [string, string] => [i.id, i.number ?? '']));
      const rows = pays.map((p) => ({ date: formatDateTr(p.date), party: names.get(p.partyId) ?? '', account: accs.get(p.accountId) ?? '', method: t(`payment.methods.${p.method}`), amount: p.amountMinor,
        invoices: p.allocations.map((a) => invNo.get(a.invoiceId) || a.invoiceId).join(', '), status: p.status === 'cancelled' ? t('payment.cancelled') : '' }));
      const tot = pays.filter((p) => p.status === 'active').reduce((s, p) => s + p.amountMinor, 0);
      return { title, range: rangeText(o), columns: [{ key: 'date', label: t('payment.date') }, { key: 'party', label: t('invoice.party') }, { key: 'account', label: t('cashBank.account') }, { key: 'method', label: t('payment.method') }, mc('amount', t('payment.amount')), { key: 'invoices', label: t('reports.invoices') }, { key: 'status', label: t('invoice.status') }], rows,
        summary: [[t('reports.total'), tot, true], [t('reports.count'), rows.length]] };
    }
  }
}
