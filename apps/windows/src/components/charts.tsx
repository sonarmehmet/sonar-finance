/** Bağımlılıksız SVG grafikler (Genel Bakış). Renkler token değişkenlerinden. */
import { formatMinorTry } from '@/core/money';

export interface Series { key: string; label: string; color: string; values: number[] }

const compact = (minor: number): string => {
  const v = Math.abs(minor) / 100;
  const s = v >= 1e6 ? `${(v / 1e6).toFixed(1)}M` : v >= 1e3 ? `${(v / 1e3).toFixed(0)}B` : `${Math.round(v)}`;
  return minor < 0 ? `-${s}` : s;
};

/** Yan yana sütun grafiği; isteğe bağlı çizgi serisi (ör. net). Negatif değerleri destekler. */
export function ColumnChart({ labels, bars, line, height = 220 }: { labels: string[]; bars: Series[]; line?: Series; height?: number }) {
  const W = 720, padL = 44, padB = 22, padT = 8, H = height;
  const all = [...bars.flatMap((s) => s.values), ...(line?.values ?? []), 0];
  const max = Math.max(...all), min = Math.min(...all);
  const span = max - min || 1;
  const y = (v: number) => padT + (1 - (v - min) / span) * (H - padT - padB);
  const gw = (W - padL) / labels.length;
  const bw = Math.max(4, (gw * 0.7) / bars.length);
  const ticks = [min, min + span / 2, max];
  return (
    <div>
      <svg viewBox={`0 0 ${W} ${H}`} width="100%" role="img" aria-label="grafik">
        {ticks.map((tk, i) => (
          <g key={i}><line x1={padL} x2={W} y1={y(tk)} y2={y(tk)} stroke="var(--c-border)" strokeWidth={1} />
            <text x={padL - 6} y={y(tk) + 4} textAnchor="end" fontSize={10} fill="var(--c-textSecondary)">{compact(tk)}</text></g>))}
        {labels.map((l, i) => (
          <g key={l}>
            {bars.map((s, j) => {
              const v = s.values[i] ?? 0, x = padL + i * gw + gw * 0.15 + j * bw;
              const y0 = y(0), y1 = y(v);
              return <rect key={s.key} x={x} y={Math.min(y0, y1)} width={bw - 1} height={Math.max(1, Math.abs(y0 - y1))} fill={s.color} rx={2}><title>{`${s.label}: ${formatMinorTry(v)}`}</title></rect>;
            })}
            <text x={padL + i * gw + gw / 2} y={H - 6} textAnchor="middle" fontSize={10} fill="var(--c-textSecondary)">{l.slice(5)}</text>
          </g>))}
        {line && <polyline fill="none" stroke={line.color} strokeWidth={2} points={line.values.map((v, i) => `${padL + i * gw + gw / 2},${y(v)}`).join(' ')} />}
      </svg>
      <div style={{ display: 'flex', gap: 16, fontSize: 'var(--fs-caption)', color: 'var(--c-textSecondary)' }}>
        {[...bars, ...(line ? [line] : [])].map((s) => <span key={s.key}><span style={{ display: 'inline-block', width: 10, height: 10, background: s.color, borderRadius: 2, marginRight: 6 }} />{s.label}</span>)}
      </div>
    </div>
  );
}

/** Küçük trend çizgisi (kart içi). */
export function Sparkline({ values, color }: { values: number[]; color: string }) {
  const W = 120, H = 32;
  const max = Math.max(...values, 0), min = Math.min(...values, 0), span = max - min || 1;
  const pts = values.map((v, i) => `${(i / Math.max(1, values.length - 1)) * W},${H - 2 - ((v - min) / span) * (H - 4)}`).join(' ');
  return <svg viewBox={`0 0 ${W} ${H}`} width={W} height={H} aria-hidden="true"><polyline points={pts} fill="none" stroke={color} strokeWidth={2} /></svg>;
}
