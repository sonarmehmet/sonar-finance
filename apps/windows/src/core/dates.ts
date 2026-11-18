/** İş tarihleri `YYYY-MM-DD` metin (docs/02). Saat dilimi sorunu olmasın diye Date yalnız üretimde kullanılır. */
export function parseIsoDate(s: string): Date | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
  if (!m) return null;
  const y = Number(m[1]), mo = Number(m[2]), d = Number(m[3]);
  const dt = new Date(Date.UTC(y, mo - 1, d));
  return dt.getUTCFullYear() === y && dt.getUTCMonth() === mo - 1 && dt.getUTCDate() === d ? dt : null;
}

export const yearOf = (iso: string): string => iso.slice(0, 4);
export const monthKey = (iso: string): string => iso.slice(0, 7);

export function addDays(iso: string, days: number): string {
  const d = parseIsoDate(iso);
  if (!d) return iso;
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

/** 2026-11-17 -> 17.11.2026 (gösterim). */
export function formatDateTr(iso: string): string {
  const d = parseIsoDate(iso);
  return d ? `${iso.slice(8, 10)}.${iso.slice(5, 7)}.${iso.slice(0, 4)}` : iso;
}
