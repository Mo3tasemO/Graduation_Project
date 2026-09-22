/**
 * MindSpeak auth client. Talks to the real server in E:\app\server (see README.md).
 * Passwords are hashed and codes are emailed by the SERVER; nothing sensitive is stored here.
 */
import type { Profile, Settings, HistoryItem, AppNotification } from '../store';
import { API_URL } from '../config';
import { session } from '../session';

export class AuthError extends Error {
  code: string;
  devCode?: string;
  constructor(message: string, code = 'ERROR', devCode?: string) {
    super(message);
    this.code = code;
    this.devCode = devCode;
  }
}

// ------------------------------------------------------------------ validation (shared with the UI)
export const isGmail = (e: string) => /^[^\s@]+@gmail\.com$/i.test(e.trim());

export function passwordChecks(pw: string) {
  return { length: pw.length >= 8, number: /\d/.test(pw), special: /[^A-Za-z0-9]/.test(pw) };
}
export const passwordOk = (pw: string) => Object.values(passwordChecks(pw)).every(Boolean);

export const cleanPhone = (p: string) => {
  const t = p.trim();
  return (t.startsWith('+') ? '+' : '') + t.replace(/\D/g, '');
};
export const phoneOk = (p: string) => {
  const d = p.replace(/\D/g, '');
  return d.length >= 11 && d.length <= 15;
};

/** "DD/MM/YYYY" -> "YYYY-MM-DD", or null when invalid / in the future. */
export function parseBirthDate(s: string): string | null {
  const m = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(s.trim());
  if (!m) return null;
  const [d, mo, y] = [+m[1], +m[2], +m[3]];
  const dt = new Date(y, mo - 1, d);
  if (dt.getFullYear() !== y || dt.getMonth() !== mo - 1 || dt.getDate() !== d) return null;
  if (dt.getTime() > Date.now() || y < 1900) return null;
  return `${y}-${String(mo).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
}

export function ageFrom(iso: string): number {
  const b = new Date(iso);
  const n = new Date();
  let a = n.getFullYear() - b.getFullYear();
  if (n.getMonth() < b.getMonth() || (n.getMonth() === b.getMonth() && n.getDate() < b.getDate())) a--;
  return a;
}


// ------------------------------------------------------------------ server calls
export type ServerData = {
  profile?: Partial<Profile>;
  settings?: Settings | null;
  history?: HistoryItem[];
  notifications?: AppNotification[];
  calibrated?: boolean;
};
export type LoginResult = { token: string; user: Partial<Profile>; data: ServerData | null };

async function request<T>(path: string, opts: { method?: string; body?: unknown; auth?: boolean } = {}): Promise<T> {
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), 15000);
  try {
    const res = await fetch(API_URL + path, {
      method: opts.method ?? 'POST',
      headers: { 'Content-Type': 'application/json', ...(opts.auth && session.token ? { Authorization: `Bearer ${session.token}` } : {}) },
      body: opts.body === undefined ? undefined : JSON.stringify(opts.body),
      signal: ctl.signal,
    });
    const json = await res.json().catch(() => ({}));
    if (!res.ok) throw new AuthError(json?.error?.message ?? 'Something went wrong', json?.error?.code ?? 'ERROR', json?.error?.devCode);
    return json as T;
  } catch (e) {
    if (e instanceof AuthError) throw e;
    throw new AuthError('Cannot reach the MindSpeak server. Make sure it is running and your phone is on the same Wi-Fi.', 'NETWORK');
  } finally {
    clearTimeout(timer);
  }
}

type CodeInfo = { devCode?: string; emailSent?: boolean };

export const auth = {
  /** Creates an unverified account and emails a 6-digit code. */
  async register(i: { username: string; email: string; password: string; birthDate: string; phone: string; photo?: string }) {
    const birth = parseBirthDate(i.birthDate);
    if (!birth) throw new AuthError('Enter a valid birth date (DD/MM/YYYY)', 'BAD_BIRTH');
    return request<{ email: string } & CodeInfo>('/auth/register', {
      body: { username: i.username.trim(), email: i.email, password: i.password, birthDate: birth, phone: cleanPhone(i.phone), photo: i.photo },
    });
  },
  resendCode: (purpose: 'register' | 'reset', email: string) => request<CodeInfo>('/auth/resend-code', { body: { purpose, email } }),
  verifyEmail: (email: string, code: string) => request<{ ok: true }>('/auth/verify-email', { body: { email, code } }),
  login: (email: string, password: string) => request<LoginResult>('/auth/login', { body: { email, password } }),
  loginBiometric: (email: string, deviceToken: string) => request<LoginResult>('/auth/login-biometric', { body: { email, deviceToken } }),
  requestPasswordReset: (email: string) => request<{ email: string } & CodeInfo>('/auth/forgot-password', { body: { email } }),
  verifyResetCode: async (email: string, code: string) => (await request<{ token: string }>('/auth/verify-reset-code', { body: { email, code } })).token,
  resetPassword: (email: string, token: string, password: string) => request<{ ok: true }>('/auth/reset-password', { body: { email, token, password } }),

  /** Asks the server for a secret this phone can use for fingerprint / Face ID login. */
  enableBiometric: async () => (await request<{ deviceToken: string }>('/me/biometric/enable', { auth: true })).deviceToken,
  disableBiometric: (deviceToken: string) => request('/me/biometric/disable', { auth: true, body: { deviceToken } }),

  /** Saves the patient's profile / settings / history to the cloud database. */
  pushData: (d: ServerData) => request('/me/data', { method: 'PUT', auth: true, body: d }),
};
