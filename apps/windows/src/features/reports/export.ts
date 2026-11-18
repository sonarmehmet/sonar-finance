/** Rapor dışa aktarma (docs/08 §6). Excel: ilk sayfa özet, ikinci sayfa detay; para hücreleri sayı (kuruş/100). PDF: yazdır → "PDF olarak kaydet". */
import * as XLSX from 'xlsx';

export interface Column { key: string; label: string; money?: boolean; num?: boolean }
export type Cell = string | number | undefined;
export interface ReportData { title: string; range: string; columns: Column[]; rows: Record<string, Cell>[]; summary: [string, Cell, boolean?][] }

export function exportXlsx(r: ReportData, company: string, filename: string): void {
  const book = XLSX.utils.book_new();
  const head: Cell[][] = [[company], [r.title], [r.range], [`Oluşturma: ${new Date().toLocaleString('tr-TR')}`], [], ...r.summary.map(([k, v, money]) => [k, money && typeof v === 'number' ? v / 100 : v])];
  const s1 = XLSX.utils.aoa_to_sheet(head);
  s1['!cols'] = [{ wch: 32 }, { wch: 20 }];
  XLSX.utils.book_append_sheet(book, s1, 'Özet');
  const aoa: Cell[][] = [r.columns.map((c) => c.label), ...r.rows.map((row) => r.columns.map((c) => (c.money && typeof row[c.key] === 'number' ? (row[c.key] as number) / 100 : row[c.key])))];
  const s2 = XLSX.utils.aoa_to_sheet(aoa);
  r.columns.forEach((c, i) => { if (c.money) for (let y = 1; y < aoa.length; y++) { const cell = s2[XLSX.utils.encode_cell({ r: y, c: i })]; if (cell) cell.z = '#,##0.00'; } });
  s2['!cols'] = r.columns.map(() => ({ wch: 18 }));
  XLSX.utils.book_append_sheet(book, s2, 'Detay');
  XLSX.writeFile(book, filename.endsWith('.xlsx') ? filename : `${filename}.xlsx`);
}

export const printReport = (): void => window.print();
