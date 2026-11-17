import { useEffect, useState } from 'react';
import { onSnapshot, type DocumentData, type DocumentReference } from 'firebase/firestore';

export interface DocState<T> { data: T | null; loading: boolean; error: Error | null }

/** Tek belge dinleyicisi. `ref` null ise dinlenmez. */
export function useDocSnapshot<T>(ref: DocumentReference<DocumentData> | null, key: string, map: (id: string, x: DocumentData) => T): DocState<T> {
  const [s, setS] = useState<DocState<T>>({ data: null, loading: true, error: null });
  useEffect(() => {
    if (!ref) { setS({ data: null, loading: false, error: null }); return; }
    setS((x) => ({ ...x, loading: true }));
    return onSnapshot(ref, (snap) => setS({ data: snap.exists() ? map(snap.id, snap.data()) : null, loading: false, error: null }),
      (error) => setS({ data: null, loading: false, error }));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);
  return s;
}
