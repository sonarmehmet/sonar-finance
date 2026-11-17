import { initializeApp } from 'firebase/app';
import { getAuth, connectAuthEmulator, browserLocalPersistence, setPersistence } from 'firebase/auth';
import {
  initializeFirestore, persistentLocalCache, persistentSingleTabManager, connectFirestoreEmulator,
} from 'firebase/firestore';

const useEmulator = import.meta.env.VITE_USE_EMULATOR === 'true';

const app = initializeApp({
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY || 'demo-key',
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN || 'demo-sonar-finance.firebaseapp.com',
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID || 'demo-sonar-finance',
  appId: import.meta.env.VITE_FIREBASE_APP_ID || 'demo-app-id',
});

export const auth = getAuth(app);
void setPersistence(auth, browserLocalPersistence);

// docs/05: yerel önbellek = Firestore kalıcı önbelleği (IndexedDB); ayrı SQLite yok.
export const db = initializeFirestore(app, {
  localCache: persistentLocalCache({ tabManager: persistentSingleTabManager(undefined) }),
});

if (useEmulator) {
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
  connectFirestoreEmulator(db, '127.0.0.1', 8080);
}

export const isEmulator = useEmulator;
