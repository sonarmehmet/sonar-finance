import { useState, type FormEvent } from 'react';
import { t } from '@/core/i18n';
import { useAuth } from '@/core/auth/AuthProvider';
import { firebaseConfigured } from '@/core/firebase';

function errorKey(code: string): string {
  switch (code) {
    case 'auth/invalid-credential':
    case 'auth/wrong-password':
    case 'auth/user-not-found':
    case 'auth/invalid-email': return 'auth.errors.invalidCredential';
    case 'auth/network-request-failed': return 'auth.errors.network';
    case 'auth/too-many-requests': return 'auth.errors.tooManyRequests';
    default: return 'auth.errors.generic';
  }
}

export function LoginPage({ initialError }: { initialError?: string }) {
  const { signIn } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(initialError ?? null);

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (!email.trim() || !password) { setError(t('auth.required')); return; }
    setBusy(true); setError(null);
    try { await signIn(email, password); }
    catch (err) { setError(t(errorKey((err as { code?: string }).code ?? ''))); }
    finally { setBusy(false); }
  }

  return (
    <div className="login-wrap">
      <form className="card login" onSubmit={submit}>
        <img className="login-logo" src="/logo-mark.png" alt="SM" />
        <h2>{t('auth.title')}</h2>
        <div className="sub">{t('auth.subtitle')}</div>
        {!firebaseConfigured && <div className="error" role="alert">{t('auth.notConfigured')}</div>}
        <div className="field">
          <label htmlFor="email">{t('auth.email')}</label>
          <input id="email" type="text" autoCapitalize="none" autoComplete="username" value={email} onChange={(e) => setEmail(e.target.value)} />
        </div>
        <div className="field">
          <label htmlFor="pw">{t('auth.password')}</label>
          <input id="pw" type="password" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} />
        </div>
        {error && <div className="error" role="alert">{error}</div>}
        <button className="btn" style={{ width: '100%', justifyContent: 'center' }} disabled={busy}>{t('auth.signIn')}</button>
        <div className="tagline">{t('auth.tagline')}</div>
      </form>
    </div>
  );
}
