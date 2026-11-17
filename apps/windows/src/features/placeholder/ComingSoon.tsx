import { t } from '@/core/i18n';

/** Henüz yazılmamış modüller için geçici ekran (üretimde sahte veri gösterilmez). */
export function ComingSoon({ menuKey }: { menuKey: string }) {
  return (
    <div className="card empty">
      <h2 style={{ marginTop: 0 }}>{t(`menu.${menuKey}`)}</h2>
      <p>{t('common.comingSoon')}</p>
    </div>
  );
}
