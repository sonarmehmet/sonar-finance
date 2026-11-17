import { useState } from 'react';
import { Dialog } from '@/components/Dialog';
import { useToast } from '@/components/Toast';
import { t } from '@/core/i18n';
import { useAuth } from '@/core/auth/AuthProvider';
import { partyRepo } from '@/data/repositories';
import type { Party, PartyKind, PartyMaster } from '@/data/models';

type Errors = Partial<Record<'name' | 'kinds' | 'taxNo' | 'email', string>>;

export function PartyForm({ party, onClose, onSaved }: { party?: Party; onClose(): void; onSaved?(id: string): void }) {
  const { companyId } = useAuth();
  const toast = useToast();
  const [m, setM] = useState<PartyMaster>(() => party
    ? { kinds: party.kinds, name: party.name, taxOffice: party.taxOffice, taxNo: party.taxNo, phone: party.phone, email: party.email, address: party.address, notes: party.notes, active: party.active }
    : { kinds: ['customer'], name: '', taxOffice: '', taxNo: '', phone: '', email: '', address: '', notes: '', active: true });
  const [errors, setErrors] = useState<Errors>({});
  const [busy, setBusy] = useState(false);

  const set = <K extends keyof PartyMaster>(k: K, v: PartyMaster[K]) => setM((s) => ({ ...s, [k]: v }));
  const toggleKind = (k: PartyKind) => set('kinds', m.kinds.includes(k) ? m.kinds.filter((x) => x !== k) : [...m.kinds, k]);

  function validate(): Errors {
    const e: Errors = {};
    if (!m.name.trim()) e.name = t('validation.required');
    if (m.kinds.length === 0) e.kinds = t('validation.kindRequired');
    if (m.taxNo.trim() && !/^\d{10,11}$/.test(m.taxNo.trim())) e.taxNo = t('validation.invalidTaxNo');
    if (m.email.trim() && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(m.email.trim())) e.email = t('validation.required');
    return e;
  }

  async function save() {
    if (!companyId) return;
    const e = validate();
    setErrors(e);
    if (Object.keys(e).length) return;
    setBusy(true);
    const clean: PartyMaster = {
      ...m, name: m.name.trim(), taxOffice: m.taxOffice.trim(), taxNo: m.taxNo.trim(), phone: m.phone.trim(),
      email: m.email.trim(), address: m.address.trim(), notes: m.notes.trim(),
    };
    try {
      if (party) {
        const synced = await partyRepo.update(companyId, party.id, clean);
        toast(synced ? 'success' : 'info', synced ? t('messages.saved') : t('messages.queued'));
        onSaved?.(party.id);
      } else {
        const r = await partyRepo.create(companyId, clean);
        toast(r.synced ? 'success' : 'info', r.synced ? t('messages.saved') : t('messages.queued'));
        onSaved?.(r.id);
      }
      onClose();
    } catch (err) {
      toast('error', `${t('messages.saveFailed')}: ${(err as Error).message}`);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Dialog title={party ? t('party.editParty') : t('party.newParty')} onClose={onClose}
      footer={<>
        <button className="btn secondary" onClick={onClose}>{t('common.cancel')}</button>
        <button className="btn" onClick={() => void save()} disabled={busy}>{t('common.save')}</button>
      </>}>
      <div className={`field ${errors.name ? 'err' : ''}`}>
        <label htmlFor="pf-name">{t('party.name')}</label>
        <input id="pf-name" value={m.name} autoFocus onChange={(e) => set('name', e.target.value)} />
        {errors.name && <span className="msg">{errors.name}</span>}
      </div>
      <div className="field">
        <label>{t('party.kind')}</label>
        <div style={{ display: 'flex', gap: 24 }}>
          <label className="check"><input type="checkbox" checked={m.kinds.includes('customer')} onChange={() => toggleKind('customer')} />{t('party.customer')}</label>
          <label className="check"><input type="checkbox" checked={m.kinds.includes('supplier')} onChange={() => toggleKind('supplier')} />{t('party.supplier')}</label>
        </div>
        {errors.kinds && <span className="msg">{errors.kinds}</span>}
      </div>
      <div className="grid2">
        <div className="field"><label>{t('fields.taxOffice')}</label><input value={m.taxOffice} onChange={(e) => set('taxOffice', e.target.value)} /></div>
        <div className={`field ${errors.taxNo ? 'err' : ''}`}><label>{t('fields.taxNo')}</label>
          <input value={m.taxNo} inputMode="numeric" onChange={(e) => set('taxNo', e.target.value)} />
          {errors.taxNo && <span className="msg">{errors.taxNo}</span>}
        </div>
        <div className="field"><label>{t('party.phone')}</label><input value={m.phone} onChange={(e) => set('phone', e.target.value)} /></div>
        <div className={`field ${errors.email ? 'err' : ''}`}><label>{t('fields.email')}</label><input value={m.email} onChange={(e) => set('email', e.target.value)} />
          {errors.email && <span className="msg">{errors.email}</span>}
        </div>
      </div>
      <div className="field"><label>{t('fields.address')}</label><input value={m.address} onChange={(e) => set('address', e.target.value)} /></div>
      <div className="field"><label>{t('fields.notes')}</label><textarea rows={3} value={m.notes} onChange={(e) => set('notes', e.target.value)} /></div>
      <label className="check"><input type="checkbox" checked={m.active} onChange={(e) => set('active', e.target.checked)} />{t('fields.active')}</label>
    </Dialog>
  );
}
