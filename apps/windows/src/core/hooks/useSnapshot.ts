import { useEffect, useRef, useState } from 'react';
import { onSnapshot, type DocumentData, type Query, type QueryDocumentSnapshot } from 'firebase/firestore';

export interface SnapshotState<T> {
  data: T[];
  loading: boolean;
  error: Error | null;
  /** Sunucuya henüz gitmemiş yazma var (docs/05 senkron rozeti için). */
  pending: boolean;
}

/** Sorgu dinleyicisi. `make` null dönerse dinleme yapılmaz. `deps` değişince yeniden bağlanır.
 * Spark kotası: dinleyiciyi yalnız ekran açıkken tut, sorgulara limit koy. */
export function useQuerySnapshot<T>(
  make: () => Query<DocumentData> | null,
  deps: readonly unknown[],
  map: (d: QueryDocumentSnapshot<DocumentData>) => T,
): SnapshotState<T> {
  const [state, setState] = useState<SnapshotState<T>>({ data: [], loading: true, error: null, pending: false });
  const mapRef = useRef(map);
  mapRef.current = map;
  const makeRef = useRef(make);
  makeRef.current = make;

  useEffect(() => {
    const q = makeRef.current();
    if (!q) { setState({ data: [], loading: false, error: null, pending: false }); return; }
    setState((s) => ({ ...s, loading: true, error: null }));
    return onSnapshot(
      q,
      { includeMetadataChanges: true },
      (snap) => setState({
        data: snap.docs.map((d) => mapRef.current(d)),
        loading: false, error: null, pending: snap.metadata.hasPendingWrites,
      }),
      (error) => setState((s) => ({ ...s, loading: false, error })),
    );
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);

  return state;
}
