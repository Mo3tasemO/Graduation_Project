import express from 'express';
import cors from 'cors';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import rateLimit from 'express-rate-limit';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { db, DATA_DIR } from './db.js';
import { sendCode, mailConfigured } from './mailer.js';
import { adminRouter } from './admin.js';

const PORT = Number(process.env.PORT || 4000);
// while true, the code is also returned to the app so you can test without email. Turn off in production.
const DEV_SHOW_CODE = (process.env.DEV_SHOW_CODE ?? (mailConfigured ? 'false' : 'true')) === 'true';
const CODE_TTL = 10 * 60 * 1000;
const MAX_ATTEMPTS = 5;

// secrets are generated once and kept in server/data (never commit that folder)
function secret(name) {
  const f = path.join(DATA_DIR, name);
  if (!fs.existsSync(f)) fs.writeFileSync(f, crypto.randomBytes(32).toString('hex'));
  return fs.readFileSync(f, 'utf8').trim();
}
const JWT_SECRET = process.env.JWT_SECRET || secret('jwt.secret');
export const ADMIN_KEY = process.env.ADMIN_KEY || secret('admin.key');

// ------------------------------------------------------------------ validation (same rules as the app)
const isGmail = (e) => /^[^\s@]+@gmail\.com$/i.test(e);
const passwordOk = (p) => typeof p === 'string' && p.length >= 8 && /\d/.test(p) && /[^A-Za-z0-9]/.test(p) && p.length <= 100;
const phoneOk = (p) => {
  const d = String(p).replace(/\D/g, '');
  return d.length >= 11 && d.length <= 15;
};
const usernameOk = (u) => /^[A-Za-z0-9_.]{3,20}$/.test(u);
const birthOk = (iso) => {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso || '');
  if (!m) return false;
  const d = new Date(+m[1], +m[2] - 1, +m[3]);
  return d.getFullYear() === +m[1] && d.getMonth() === +m[2] - 1 && d.getDate() === +m[3] && d <= new Date() && +m[1] >= 1900;
};

class HttpError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}
const bad = (code, message, status = 400) => new HttpError(status, code, message);

const sha = (s) => crypto.createHash('sha256').update(s).digest('hex');
const norm = (e) => String(e || '').trim().toLowerCase();
const json = (s, fallback) => {
  try {
    return s ? JSON.parse(s) : fallback;
  } catch {
    return fallback;
  }
};

function newPatientId() {
  for (;;) {
    const id = String(new Date().getFullYear()) + String(crypto.randomInt(10000, 100000));
    if (!db.prepare('SELECT 1 FROM users WHERE patient_id = ?').get(id)) return id;
  }
}

async function issueCode(email, purpose) {
  const code = String(crypto.randomInt(100000, 1000000));
  db.prepare('INSERT OR REPLACE INTO otps (email, purpose, code_hash, expires, attempts) VALUES (?,?,?,?,0)').run(email, purpose, sha(code), Date.now() + CODE_TTL);
  let emailSent = false;
  try {
    emailSent = await sendCode(email, code, purpose);
  } catch (e) {
    console.error('[mail] failed to send:', e.message);
    if (!DEV_SHOW_CODE) throw bad('MAIL_FAILED', 'We could not send the email. Please try again later.', 502);
  }
  return { emailSent, ...(DEV_SHOW_CODE ? { devCode: code } : {}) };
}

function checkCode(email, purpose, code) {
  const row = db.prepare('SELECT * FROM otps WHERE email = ? AND purpose = ?').get(email, purpose);
  if (!row) throw bad('NO_CODE', 'No code was requested. Please request a new one.');
  if (Date.now() > row.expires) {
    db.prepare('DELETE FROM otps WHERE email = ? AND purpose = ?').run(email, purpose);
    throw bad('EXPIRED', 'This code has expired. Request a new one.');
  }
  if (row.attempts >= MAX_ATTEMPTS) {
    db.prepare('DELETE FROM otps WHERE email = ? AND purpose = ?').run(email, purpose);
    throw bad('LOCKED', 'Too many wrong attempts. Request a new code.', 429);
  }
  if (row.code_hash !== sha(String(code).trim())) {
    db.prepare('UPDATE otps SET attempts = attempts + 1 WHERE email = ? AND purpose = ?').run(email, purpose);
    throw bad('BAD_CODE', `Incorrect code. ${MAX_ATTEMPTS - row.attempts - 1} attempts left.`);
  }
  db.prepare('DELETE FROM otps WHERE email = ? AND purpose = ?').run(email, purpose);
}

const ageFrom = (iso) => {
  const b = new Date(iso);
  const n = new Date();
  let a = n.getFullYear() - b.getFullYear();
  if (n.getMonth() < b.getMonth() || (n.getMonth() === b.getMonth() && n.getDate() < b.getDate())) a--;
  return a;
};

const publicUser = (u) => ({
  email: u.email,
  name: u.username,
  id: u.patient_id,
  birthDate: u.birth_date,
  age: String(ageFrom(u.birth_date)),
  phone: u.phone,
  photo: u.photo || '',
});

const userData = (uid) => {
  const d = db.prepare('SELECT * FROM user_data WHERE user_id = ?').get(uid);
  if (!d) return null;
  return {
    profile: json(d.profile, {}),
    settings: json(d.settings, null),
    history: json(d.history, []),
    notifications: json(d.notifications, []),
    calibrated: !!d.calibrated,
  };
};

const session = (u) => {
  db.prepare("UPDATE users SET last_login_at = datetime('now') WHERE id = ?").run(u.id);
  return { token: jwt.sign({ uid: u.id }, JWT_SECRET, { expiresIn: '30d' }), user: publicUser(u), data: userData(u.id) };
};

// ------------------------------------------------------------------ app
const app = express();
app.set('trust proxy', 1);
app.use(cors());
app.use(express.json({ limit: '6mb' }));

const authLimiter = rateLimit({ windowMs: 15 * 60 * 1000, limit: 60, standardHeaders: true, legacyHeaders: false, message: { error: { code: 'RATE', message: 'Too many attempts. Try again in a few minutes.' } } });
const wrap = (fn) => (req, res, next) => Promise.resolve(fn(req, res)).then((r) => r !== undefined && res.json(r)).catch(next);

// convenience: opening http://localhost:4000 from THIS computer jumps to the admin dashboard
app.get('/', (req, res) => {
  const a = req.socket.remoteAddress || '';
  if (a === '127.0.0.1' || a === '::1' || a === '::ffff:127.0.0.1') return res.redirect(`/admin?key=${ADMIN_KEY}`);
  res.type('text').send('MindSpeak server is running.');
});

app.get('/health', (_req, res) => res.json({ ok: true, mail: mailConfigured ? 'smtp' : 'console', devShowCode: DEV_SHOW_CODE }));

const auth = express.Router();
auth.use(authLimiter);

auth.post(
  '/register',
  wrap(async (req) => {
    const email = norm(req.body.email);
    const { password, phone, photo } = req.body;
    const username = String(req.body.username || '').trim();
    const birthDate = req.body.birthDate;
    if (!usernameOk(username)) throw bad('BAD_USERNAME', 'Username must be 3-20 characters: letters, numbers, . or _');
    if (!isGmail(email)) throw bad('BAD_EMAIL', 'Only Gmail addresses (@gmail.com) are allowed');
    if (!passwordOk(password)) throw bad('BAD_PASSWORD', 'Password must be 8+ characters with a number and a special character');
    if (!birthOk(birthDate)) throw bad('BAD_BIRTH', 'Enter a valid birth date');
    if (!phoneOk(phone)) throw bad('BAD_PHONE', 'Phone number must have at least 11 digits');
    if (photo && (typeof photo !== 'string' || photo.length > 4_000_000)) throw bad('BAD_PHOTO', 'Photo is too large');

    const existing = db.prepare('SELECT * FROM users WHERE email = ?').get(email);
    if (existing?.verified) throw bad('EXISTS', 'An account with this email already exists', 409);
    const taken = db.prepare('SELECT id FROM users WHERE username_lc = ?').get(username.toLowerCase());
    if (taken && taken.id !== existing?.id) throw bad('USERNAME_TAKEN', 'This username is already taken', 409);

    const hash = await bcrypt.hash(password, 10);
    if (existing) {
      db.prepare('UPDATE users SET username=?, username_lc=?, password_hash=?, birth_date=?, phone=?, photo=? WHERE id=?').run(username, username.toLowerCase(), hash, birthDate, String(phone).trim(), photo || null, existing.id);
    } else {
      db.prepare('INSERT INTO users (patient_id, username, username_lc, email, password_hash, birth_date, phone, photo) VALUES (?,?,?,?,?,?,?,?)').run(newPatientId(), username, username.toLowerCase(), email, hash, birthDate, String(phone).trim(), photo || null);
    }
    return { email, ...(await issueCode(email, 'register')) };
  }),
);

auth.post(
  '/resend-code',
  wrap(async (req) => {
    const email = norm(req.body.email);
    const purpose = req.body.purpose === 'reset' ? 'reset' : 'register';
    const u = db.prepare('SELECT * FROM users WHERE email = ?').get(email);
    if (!u || (purpose === 'register' && u.verified) || (purpose === 'reset' && !u.verified)) return { ok: true };
    return { ok: true, ...(await issueCode(email, purpose)) };
  }),
);

auth.post(
  '/verify-email',
  wrap(async (req) => {
    const email = norm(req.body.email);
    checkCode(email, 'register', req.body.code);
    db.prepare('UPDATE users SET verified = 1 WHERE email = ?').run(email);
    return { ok: true };
  }),
);

auth.post(
  '/login',
  wrap(async (req) => {
    const email = norm(req.body.email);
    const u = db.prepare('SELECT * FROM users WHERE email = ?').get(email);
    // same message for "no such user" and "wrong password"
    if (!u || !(await bcrypt.compare(String(req.body.password || ''), u.password_hash))) throw bad('INVALID', 'Incorrect email or password', 401);
    if (!u.verified) {
      const c = await issueCode(email, 'register');
      const e = bad('UNVERIFIED', 'Please verify your email first. We sent you a new code.', 403);
      e.extra = c;
      throw e;
    }
    return session(u);
  }),
);

auth.post(
  '/forgot-password',
  wrap(async (req) => {
    const email = norm(req.body.email);
    if (!isGmail(email)) throw bad('BAD_EMAIL', 'Only Gmail addresses (@gmail.com) are allowed');
    const u = db.prepare('SELECT * FROM users WHERE email = ? AND verified = 1').get(email);
    // always look successful so nobody can probe which emails exist
    return { email, ...(u ? await issueCode(email, 'reset') : {}) };
  }),
);

auth.post(
  '/verify-reset-code',
  wrap(async (req) => {
    const email = norm(req.body.email);
    checkCode(email, 'reset', req.body.code);
    const token = crypto.randomBytes(24).toString('hex');
    db.prepare('INSERT OR REPLACE INTO reset_tokens (email, token_hash, expires) VALUES (?,?,?)').run(email, sha(token), Date.now() + CODE_TTL);
    return { token };
  }),
);

auth.post(
  '/reset-password',
  wrap(async (req) => {
    const email = norm(req.body.email);
    const row = db.prepare('SELECT * FROM reset_tokens WHERE email = ?').get(email);
    if (!row || Date.now() > row.expires || row.token_hash !== sha(String(req.body.token || ''))) throw bad('BAD_TOKEN', 'Reset session expired. Start again.', 401);
    if (!passwordOk(req.body.password)) throw bad('BAD_PASSWORD', 'Password must be 8+ characters with a number and a special character');
    const u = db.prepare('SELECT id FROM users WHERE email = ?').get(email);
    db.prepare('UPDATE users SET password_hash = ? WHERE id = ?').run(await bcrypt.hash(req.body.password, 10), u.id);
    db.prepare('DELETE FROM reset_tokens WHERE email = ?').run(email);
    db.prepare('DELETE FROM devices WHERE user_id = ?').run(u.id); // a reset also signs out biometric devices
    return { ok: true };
  }),
);

// phone-side fingerprint / Face ID: the phone keeps a secret device token, the server keeps only its hash
auth.post(
  '/login-biometric',
  wrap(async (req) => {
    const u = db.prepare('SELECT * FROM users WHERE email = ? AND verified = 1').get(norm(req.body.email));
    const ok = u && db.prepare('SELECT 1 FROM devices WHERE user_id = ? AND token_hash = ?').get(u.id, sha(String(req.body.deviceToken || '')));
    if (!ok) throw bad('INVALID', 'Quick login expired. Please log in with your password.', 401);
    return session(u);
  }),
);
app.use('/auth', auth);

// ------------------------------------------------------------------ signed-in routes
const me = express.Router();
me.use((req, _res, next) => {
  try {
    const t = /^Bearer (.+)$/.exec(req.headers.authorization || '')?.[1];
    const { uid } = jwt.verify(t, JWT_SECRET);
    req.user = db.prepare('SELECT * FROM users WHERE id = ? AND verified = 1').get(uid);
    if (!req.user) throw new Error('no user');
    next();
  } catch {
    next(bad('UNAUTHORIZED', 'Please log in again.', 401));
  }
});

me.get('/data', wrap((req) => ({ user: publicUser(req.user), data: userData(req.user.id) })));

// the app pushes its state here; only whitelisted fields are stored
me.put(
  '/data',
  wrap((req) => {
    const { profile = {}, settings = null, history = [], notifications = [], calibrated = false } = req.body;
    if (!Array.isArray(history) || !Array.isArray(notifications)) throw bad('BAD_DATA', 'Invalid data');
    const { photo: _p, email: _e, id: _i, name: _n, ...extras } = profile; // identity fields live in `users`
    if (profile.phone && phoneOk(profile.phone)) db.prepare('UPDATE users SET phone = ? WHERE id = ?').run(String(profile.phone).trim(), req.user.id);
    db.prepare(
      `INSERT INTO user_data (user_id, profile, settings, history, notifications, calibrated, updated_at)
       VALUES (?,?,?,?,?,?,datetime('now'))
       ON CONFLICT(user_id) DO UPDATE SET profile=excluded.profile, settings=excluded.settings, history=excluded.history,
         notifications=excluded.notifications, calibrated=excluded.calibrated, updated_at=excluded.updated_at`,
    ).run(req.user.id, JSON.stringify(extras), JSON.stringify(settings), JSON.stringify(history.slice(0, 2000)), JSON.stringify(notifications.slice(0, 200)), calibrated ? 1 : 0);
    return { ok: true };
  }),
);

me.post(
  '/biometric/enable',
  wrap((req) => {
    const token = crypto.randomBytes(32).toString('hex');
    db.prepare('INSERT INTO devices (user_id, token_hash) VALUES (?,?)').run(req.user.id, sha(token));
    return { deviceToken: token };
  }),
);

me.post(
  '/biometric/disable',
  wrap((req) => {
    if (req.body.deviceToken) db.prepare('DELETE FROM devices WHERE user_id = ? AND token_hash = ?').run(req.user.id, sha(String(req.body.deviceToken)));
    return { ok: true };
  }),
);
app.use('/me', me);

app.use('/admin', adminRouter(ADMIN_KEY));

app.use((err, _req, res, _next) => {
  if (err instanceof HttpError) return res.status(err.status).json({ error: { code: err.code, message: err.message, ...(err.extra ?? {}) } });
  console.error(err);
  res.status(500).json({ error: { code: 'SERVER', message: 'Something went wrong on the server.' } });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`\nMindSpeak server on http://localhost:${PORT}`);
  console.log(`  email : ${mailConfigured ? 'real SMTP (' + (process.env.SMTP_USER) + ')' : 'NOT configured - codes are printed here and returned to the app (dev mode)'}`);
  console.log(`  admin : http://localhost:${PORT}/admin?key=${ADMIN_KEY}\n`);
});
