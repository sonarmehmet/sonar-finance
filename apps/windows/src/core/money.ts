/** Para, miktar ve oran yardımcıları (docs/02 "Genel kurallar", docs/04 §2).
 * Para: tam sayı kuruş (`...Minor`). Miktar: 1/1000 birim (`...Milli`). Oran: baz puan (`...Bp`).
 * Float kullanılmaz; ara çarpımlar BigInt ile yapılır (Number güvenli aralığı taşmasın). */

/** roundHalfUp(a / b) = (2a + b) / (2b), a >= 0; negatifte işaret ayrı işlenir. */
export function roundHalfUpBig(a: bigint, b: bigint): bigint {
  if (b <= 0n) throw new RangeError('böleni pozitif olmalı');
  if (a < 0n) return -roundHalfUpBig(-a, b);
  return (2n * a + b) / (2n * b);
}

export function roundHalfUp(a: number, b: number): number {
  return Number(roundHalfUpBig(BigInt(a), BigInt(b)));
}

/** roundHalfUp(a * b / c) — çarpım BigInt'te yapılır. */
export function mulDiv(a: number, b: number, c: number): number {
  return Number(roundHalfUpBig(BigInt(a) * BigInt(b), BigInt(c)));
}

function group(digits: string): string {
  return digits.replace(/\B(?=(\d{3})+(?!\d))/g, '.');
}

/** 123456 -> "1.234,56". Sembolsüz; işaret başta ("-1.234,56"). */
export function formatMinor(minor: number): string {
  const neg = minor < 0;
  const abs = Math.abs(minor);
  const major = Math.trunc(abs / 100);
  const frac = String(abs % 100).padStart(2, '0');
  return `${neg ? '-' : ''}${group(String(major))},${frac}`;
}

/** 123456 -> "1.234,56 ₺". */
export function formatMinorTry(minor: number): string {
  return `${formatMinor(minor)} ₺`;
}

/** Türkçe girdiyi kuruşa çevirir: nokta binlik, virgül ondalık. "1.250,5" -> 125050. Geçersizse null. */
export function parseMinor(input: string): number | null {
  let s = input.trim().replace(/\s|₺/g, '');
  if (!s) return null;
  let neg = false;
  if (s.startsWith('-')) { neg = true; s = s.slice(1); }
  const hasComma = s.includes(',');
  if (!hasComma && (s.match(/\./g) ?? []).length === 1) {
    // "12.5" -> ondalık sayılır; "1.250" -> binlik
    const [i, f] = s.split('.');
    if (f.length <= 2) s = `${i},${f}`;
  }
  const parts = s.split(',');
  if (parts.length > 2) return null;
  const intPart = parts[0].replace(/\./g, '');
  const fracPart = parts[1] ?? '';
  if (!/^\d+$/.test(intPart || '0') || (fracPart && !/^\d{1,2}$/.test(fracPart))) return null;
  const minor = Number(intPart || '0') * 100 + Number(fracPart.padEnd(2, '0') || '0');
  if (!Number.isSafeInteger(minor)) return null;
  return neg ? -minor : minor;
}

/** 2500 -> "2,5"; 3000 -> "3"; 1 -> "0,001". Sondaki sıfırlar atılır. */
export function formatMilli(milli: number): string {
  const neg = milli < 0;
  const abs = Math.abs(milli);
  const whole = Math.trunc(abs / 1000);
  const frac = String(abs % 1000).padStart(3, '0').replace(/0+$/, '');
  return `${neg ? '-' : ''}${group(String(whole))}${frac ? ',' + frac : ''}`;
}

/** "2,5" -> 2500, "1.000" -> 1000000. En çok 3 ondalık. Geçersizse null. */
export function parseMilli(input: string): number | null {
  let s = input.trim().replace(/\s/g, '');
  if (!s) return null;
  let neg = false;
  if (s.startsWith('-')) { neg = true; s = s.slice(1); }
  const parts = s.split(',');
  if (parts.length > 2) return null;
  const intPart = parts[0].replace(/\./g, '');
  const fracPart = parts[1] ?? '';
  if (!/^\d+$/.test(intPart || '0') || (fracPart && !/^\d{1,3}$/.test(fracPart))) return null;
  const milli = Number(intPart || '0') * 1000 + Number(fracPart.padEnd(3, '0') || '0');
  if (!Number.isSafeInteger(milli)) return null;
  return neg ? -milli : milli;
}

/** 2000 -> "%20"; 1250 -> "%12,5"; 100 -> "%1". */
export function formatBp(bp: number): string {
  const whole = Math.trunc(bp / 100);
  const frac = String(bp % 100).padStart(2, '0').replace(/0+$/, '');
  return `%${whole}${frac ? ',' + frac : ''}`;
}

/** Bugünün iş tarihi (YYYY-MM-DD, yerel saat). */
export function todayIso(d: Date = new Date()): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}
