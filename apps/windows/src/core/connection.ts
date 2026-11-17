import { useEffect, useState } from 'react';
import { onSnapshotsInSync } from 'firebase/firestore';
import { db } from './firebase';

/** docs/05: Çevrimiçi / Çevrimdışı / Senkronize ediliyor / Senkron hatası. */
export type ConnectionState = 'online' | 'offline' | 'syncing' | 'syncError';

/** Ağ durumu + (ileride) bekleyen yazma sayacı. Kuyruk ekranı W9'da bağlanır. */
export function useConnectionState(): ConnectionState {
  const [online, setOnline] = useState<boolean>(navigator.onLine);
  const [syncing, setSyncing] = useState(false);

  useEffect(() => {
    const on = () => setOnline(true);
    const off = () => setOnline(false);
    window.addEventListener('online', on);
    window.addEventListener('offline', off);
    return () => { window.removeEventListener('online', on); window.removeEventListener('offline', off); };
  }, []);

  useEffect(() => {
    // Anlık görüntüler eşitlendiğinde kısa süre "senkronize" göster (W9'da bekleyen yazma sayacıyla değişecek).
    let timer: ReturnType<typeof setTimeout> | undefined;
    const unsub = onSnapshotsInSync(db, () => {
      setSyncing(true);
      clearTimeout(timer);
      timer = setTimeout(() => setSyncing(false), 600);
    });
    return () => { unsub(); clearTimeout(timer); };
  }, []);

  if (!online) return 'offline';
  return syncing ? 'syncing' : 'online';
}
