import type { ReactNode } from 'react';
import { t } from '@/core/i18n';
import { formatMinorTry } from '@/core/money';

export function Tabs<K extends string>({ tabs, value, onChange }: {
  tabs: { key: K; label: string; disabled?: boolean }[]; value: K; onChange(k: K): void;
}) {
  return (
    <div className="tabs" role="tablist">
      {tabs.map((x) => (
        <button key={x.key} role="tab" aria-selected={value === x.key} disabled={x.disabled}
          className={`tab ${value === x.key ? 'active' : ''}`} onClick={() => onChange(x.key)}
          title={x.disabled ? t('common.comingSoon') : undefined}>{x.label}</button>
      ))}
    </div>
  );
}

export function Chip({ color, children }: { color: string; children: ReactNode }) {
  return (
    <span className="chip" style={{ color, background: `color-mix(in srgb, ${color} 16%, transparent)` }}>{children}</span>
  );
}

export function Kpi({ title, value, tone }: { title: string; value: ReactNode; tone?: 'pos' | 'neg' | 'warn' }) {
  return (
    <div className="card kpi">
      <div className="kpi-title">{title}</div>
      <div className={`kpi-value ${tone ?? ''}`}>{value}</div>
    </div>
  );
}

/** Bakiye: >0 alacak (yeşil), <0 borç (kırmızı), 0 nötr. */
export function Balance({ minor, bold }: { minor: number; bold?: boolean }) {
  const cls = minor > 0 ? 'pos' : minor < 0 ? 'neg' : '';
  return <span className={`money ${cls}`} style={bold ? { fontWeight: 600 } : undefined}>{formatMinorTry(Math.abs(minor))}</span>;
}

export function LoadingState() { return <div className="empty">{t('common.loading')}</div>; }
export function EmptyState({ text }: { text?: string }) { return <div className="empty">{text ?? t('common.empty')}</div>; }
export function ErrorState({ error }: { error: Error }) {
  return <div className="empty neg" role="alert">{t('common.error')}: {error.message}</div>;
}
