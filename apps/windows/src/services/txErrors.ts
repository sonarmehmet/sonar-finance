import { t } from '@/core/i18n';

/** İşlem hatası: `code` UI'da çevrilir (errors.* / messages.*). */
export class TxError extends Error {
  readonly code: string;
  readonly params: Record<string, string | number>;
  constructor(code: string, params: Record<string, string | number> = {}) {
    super(code);
    this.name = 'TxError';
    this.code = code;
    this.params = params;
  }
}

/** Kullanıcıya gösterilecek Türkçe metin. Firebase hatalarını da çevirir. */
export function txErrorMessage(e: unknown): string {
  if (e instanceof TxError) {
    switch (e.code) {
      case 'alreadyProcessed': return t('messages.alreadyProcessed');
      case 'insufficientStock': return t('messages.insufficientStock', e.params);
      case 'cannotCancelPaid': return t('messages.cannotCancelPaid');
      default: {
        const k = `errors.${e.code}`;
        const m = t(k, e.params);
        return m === k ? t('errors.generic') : m;
      }
    }
  }
  const code = (e as { code?: string } | null)?.code ?? '';
  if (code === 'permission-denied') return t('errors.permission');
  if (code === 'unavailable' || code === 'failed-precondition' || code === 'deadline-exceeded') return t('errors.offline');
  if (code === 'aborted') return t('errors.conflict');
  return t('errors.generic');
}
