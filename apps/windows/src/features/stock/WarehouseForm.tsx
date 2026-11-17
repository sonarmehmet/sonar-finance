import { useState } from 'react';
import { Dialog } from '@/components/Dialog';
import { useToast } from '@/components/Toast';
import { t } from '@/core/i18n';
import { useAuth } from '@/core/auth/AuthProvider';
import { warehouseRepo } from '@/data/repositories';
import type { Warehouse } from '@/data/models';

export function WarehouseForm({ warehouse, all, onClose }: { warehouse?: Warehouse; all: Warehouse[]; onClose(): void }) {
  const { companyId } = useAuth();
  const toast = useToast();
  const [name, setName] = useState(warehouse?.name ?? '');
  const [location, setLocation] = useState(warehouse?.location ?? '');
  const [isDefault, setIsDefault] = useState(warehouse?.isDefault ?? all.length === 0);
  const [active, setActive] = useState(warehouse?.active ?? true);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function save() {
    if (!companyId) return;
    if (!name.trim()) { setErr(t('validation.required')); return; }
    setBusy(true);
    try {
      const r = await warehouseRepo.save(companyId, warehouse?.id ?? null,
        { name: name.trim(), location: location.trim(), isDefault, active },
        all.filter((w) => w.isDefault).map((w) => w.id));
      toast(r.synced ? 'success' : 'info', r.synced ? t('messages.saved') : t('messages.queued'));
      onClose();
    } catch (e) {
      toast('error', `${t('messages.saveFailed')}: ${(e as Error).message}`);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Dialog title={warehouse ? t('stock.editWarehouse') : t('stock.newWarehouse')} onClose={onClose} width={460}
      footer={<>
        <button className="btn secondary" onClick={onClose}>{t('common.cancel')}</button>
        <button className="btn" onClick={() => void save()} disabled={busy}>{t('common.save')}</button>
      </>}>
      <div className={`field ${err ? 'err' : ''}`}><label>{t('stock.name')}</label>
        <input value={name} autoFocus onChange={(e) => { setName(e.target.value); setErr(null); }} />{err && <span className="msg">{err}</span>}</div>
      <div className="field"><label>{t('fields.location')}</label><input value={location} onChange={(e) => setLocation(e.target.value)} /></div>
      <label className="check"><input type="checkbox" checked={isDefault} onChange={(e) => setIsDefault(e.target.checked)} />{t('fields.isDefault')}</label>
      <label className="check"><input type="checkbox" checked={active} onChange={(e) => setActive(e.target.checked)} />{t('fields.active')}</label>
    </Dialog>
  );
}
