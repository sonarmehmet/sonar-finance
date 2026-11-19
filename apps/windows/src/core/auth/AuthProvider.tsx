import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { onAuthStateChanged, signInWithEmailAndPassword, signOut as fbSignOut, type User } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import { auth, db } from '../firebase';
import type { Company, Permission, UserProfile } from '../types';

type AuthState =
  | { status: 'loading' }
  | { status: 'signedOut' }
  | { status: 'error'; code: 'noProfile' | 'inactive' | 'generic' }
  | { status: 'ready'; user: User; profile: UserProfile; company: Company };

interface AuthApi {
  state: AuthState;
  signIn(email: string, password: string): Promise<void>;
  signOut(): Promise<void>;
  can(permission: Permission): boolean;
  isAdmin: boolean;
  companyId: string | null;
}

/** Kullanıcı adı girildiyse ("@" yok) iç alan adı eklenir: sonar -> sonar@sonar.local */
export function toEmail(input: string): string {
  const v = input.trim().toLowerCase();
  return v.includes('@') ? v : `${v}@sonar.local`;
}

const Ctx = createContext<AuthApi | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>({ status: 'loading' });

  useEffect(() => {
    return onAuthStateChanged(auth, async (user) => {
      if (!user) { setState({ status: 'signedOut' }); return; }
      setState({ status: 'loading' });
      try {
        const snap = await getDoc(doc(db, 'users', user.uid));
        if (!snap.exists()) { setState({ status: 'error', code: 'noProfile' }); return; }
        const profile = snap.data() as UserProfile;
        if (!profile.active) { setState({ status: 'error', code: 'inactive' }); return; }
        const comp = await getDoc(doc(db, 'companies', profile.companyId));
        if (!comp.exists()) { setState({ status: 'error', code: 'noProfile' }); return; }
        setState({ status: 'ready', user, profile, company: comp.data() as Company });
      } catch {
        setState({ status: 'error', code: 'generic' });
      }
    });
  }, []);

  const api = useMemo<AuthApi>(() => ({
    state,
    async signIn(email, password) { await signInWithEmailAndPassword(auth, toEmail(email), password); },
    async signOut() { await fbSignOut(auth); },
    can(permission) {
      if (state.status !== 'ready') return false;
      return state.profile.role === 'admin' || state.profile.permissions[permission] === true;
    },
    isAdmin: state.status === 'ready' && state.profile.role === 'admin',
    companyId: state.status === 'ready' ? state.profile.companyId : null,
  }), [state]);

  return <Ctx.Provider value={api}>{children}</Ctx.Provider>;
}

export function useAuth(): AuthApi {
  const v = useContext(Ctx);
  if (!v) throw new Error('useAuth, AuthProvider dışında kullanıldı');
  return v;
}
