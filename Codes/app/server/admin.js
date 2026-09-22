import express from 'express';
import crypto from 'node:crypto';
import { db } from './db.js';

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
const json = (s, f) => {
  try {
    return s ? JSON.parse(s) : f;
  } catch {
    return f;
  }
};

const CSS = `
:root{color-scheme:light dark;--bg:#F8FAFC;--card:#fff;--text:#1E293B;--mut:#64748B;--line:#E2E8F0;--pri:#2563EB}
@media(prefers-color-scheme:dark){:root{--bg:#0B1220;--card:#111B2E;--text:#F1F5F9;--mut:#94A3B8;--line:#1F2E4A}}
body{font-family:Poppins,system-ui,Segoe UI,Arial,sans-serif;background:var(--bg);color:var(--text);margin:0;padding:24px}
.wrap{max-width:1100px;margin:auto}h1{color:var(--pri);margin:0 0 4px}h2{margin:24px 0 8px}
.mut{color:var(--mut);font-size:13px}.card{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:16px;margin:12px 0;overflow-x:auto}
table{border-collapse:collapse;width:100%;font-size:14px}th,td{text-align:left;padding:8px 10px;border-bottom:1px solid var(--line);white-space:nowrap}
th{color:var(--mut);font-weight:600;font-size:12px;text-transform:uppercase}a{color:var(--pri);text-decoration:none;font-weight:600}
.pill{padding:2px 10px;border-radius:12px;font-size:12px;font-weight:600}.ok{background:#10B98122;color:#10B981}.no{background:#F59E0B22;color:#F59E0B}
img.av{width:64px;height:64px;border-radius:50%;object-fit:cover}pre{background:var(--bg);padding:12px;border-radius:10px;overflow:auto;font-size:12px}
.stats{display:flex;gap:12px;flex-wrap:wrap}.stat{flex:1;min-width:140px}.stat b{font-size:26px;display:block}
`;

const page = (title, body) => `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${esc(title)}</title><style>${CSS}</style></head><body><div class="wrap">${body}</div></body></html>`;

/** Read-only dashboard over the database. Protected by ADMIN_KEY. Password hashes are never shown. */
export function adminRouter(ADMIN_KEY) {
  const r = express.Router();
  const A = Buffer.from(ADMIN_KEY);

  r.use((req, res, next) => {
    const k = String(req.query.key || req.headers['x-admin-key'] || '');
    const B = Buffer.from(k);
    if (A.length === B.length && crypto.timingSafeEqual(A, B)) return next();
    res.status(401).send(page('Admin', '<h1>MindSpeak admin</h1><p class="mut">Add <code>?key=YOUR_ADMIN_KEY</code> to the address. The key is printed when the server starts and saved in server/data/admin.key</p>'));
  });

  const users = () =>
    db
      .prepare(
        `SELECT u.id, u.patient_id, u.username, u.email, u.phone, u.birth_date, u.verified, u.created_at, u.last_login_at,
                (photo IS NOT NULL) AS has_photo, d.history, d.notifications, d.calibrated, d.updated_at
         FROM users u LEFT JOIN user_data d ON d.user_id = u.id ORDER BY u.id DESC`,
      )
      .all();

  r.get('/api/users', (_req, res) => res.json(users().map(({ history, notifications, ...u }) => ({ ...u, history_count: json(history, []).length, notification_count: json(notifications, []).length }))));

  r.get('/', (req, res) => {
    const k = encodeURIComponent(req.query.key);
    const rows = users();
    const verified = rows.filter((u) => u.verified).length;
    const totalMsgs = rows.reduce((n, u) => n + json(u.history, []).length, 0);
    res.send(
      page(
        'MindSpeak admin',
        `<h1>MindSpeak users</h1><div class="mut">Live view of server/data/mindspeak.db</div>
        <div class="card stats"><div class="stat"><b>${rows.length}</b><span class="mut">accounts</span></div><div class="stat"><b>${verified}</b><span class="mut">verified</span></div><div class="stat"><b>${totalMsgs}</b><span class="mut">messages saved</span></div></div>
        <div class="card"><table><tr><th>Patient ID</th><th>Username</th><th>Email</th><th>Phone</th><th>Birth date</th><th>Status</th><th>Messages</th><th>Created</th><th>Last login</th></tr>
        ${rows
          .map(
            (u) => `<tr><td><a href="/admin/user/${u.id}?key=${k}">${esc(u.patient_id)}</a></td><td>${esc(u.username)}</td><td>${esc(u.email)}</td><td>${esc(u.phone)}</td><td>${esc(u.birth_date)}</td>
          <td><span class="pill ${u.verified ? 'ok' : 'no'}">${u.verified ? 'verified' : 'pending'}</span></td><td>${json(u.history, []).length}</td><td>${esc(u.created_at)}</td><td>${esc(u.last_login_at || '-')}</td></tr>`,
          )
          .join('') || '<tr><td colspan="9" class="mut">No users yet.</td></tr>'}
        </table></div>
        <p class="mut">JSON: <a href="/admin/api/users?key=${k}">/admin/api/users</a></p>`,
      ),
    );
  });

  r.get('/user/:id', (req, res) => {
    const k = encodeURIComponent(req.query.key);
    const u = db.prepare('SELECT * FROM users WHERE id = ?').get(req.params.id);
    if (!u) return res.status(404).send(page('Not found', '<p>User not found. <a href="/admin?key=' + k + '">Back</a></p>'));
    const d = db.prepare('SELECT * FROM user_data WHERE user_id = ?').get(u.id);
    const profile = json(d?.profile, {});
    const history = json(d?.history, []);
    const notes = json(d?.notifications, []);
    const devices = db.prepare('SELECT COUNT(*) AS n FROM devices WHERE user_id = ?').get(u.id).n;
    res.send(
      page(
        u.username,
        `<a href="/admin?key=${k}">&larr; All users</a>
        <div class="card" style="display:flex;gap:16px;align-items:center">${u.photo ? `<img class="av" src="${esc(u.photo)}">` : ''}<div><h1>${esc(u.username)}</h1><div class="mut">Patient ID ${esc(u.patient_id)} &middot; ${esc(u.email)}</div></div></div>
        <div class="card"><table>
          <tr><th>Phone</th><td>${esc(u.phone)}</td></tr><tr><th>Birth date</th><td>${esc(u.birth_date)}</td></tr>
          <tr><th>Verified</th><td>${u.verified ? 'yes' : 'no'}</td></tr><tr><th>Created</th><td>${esc(u.created_at)}</td></tr>
          <tr><th>Last login</th><td>${esc(u.last_login_at || '-')}</td></tr><tr><th>Biometric devices</th><td>${devices}</td></tr>
          <tr><th>Calibration</th><td>${d?.calibrated ? 'completed' : 'pending'}</td></tr><tr><th>Last sync</th><td>${esc(d?.updated_at || 'never')}</td></tr>
          <tr><th>Caregiver</th><td>${esc(profile.caregiver || '-')} ${esc(profile.caregiverRelation || '')} ${esc(profile.caregiverPhone || '')}</td></tr>
          <tr><th>Medical</th><td>${esc(profile.condition || '-')} / allergies: ${esc(profile.allergies || '-')} / blood: ${esc(profile.bloodType || '-')}</td></tr>
        </table></div>
        <h2>Message history (${history.length})</h2>
        <div class="card"><table><tr><th>When</th><th>Text</th><th>Source</th><th>Confidence</th></tr>
        ${history.map((h) => `<tr><td>${esc(new Date(h.time).toLocaleString())}</td><td>${esc(h.text)}</td><td>${esc(h.source)}</td><td>${esc(h.confidence)}%</td></tr>`).join('') || '<tr><td colspan="4" class="mut">Nothing yet.</td></tr>'}
        </table></div>
        <h2>Notifications (${notes.length})</h2>
        <div class="card"><table><tr><th>When</th><th>Type</th><th>Title</th><th>Body</th></tr>
        ${notes.map((n) => `<tr><td>${esc(new Date(n.time).toLocaleString())}</td><td>${esc(n.type)}</td><td>${esc(n.title)}</td><td>${esc(n.body)}</td></tr>`).join('') || '<tr><td colspan="4" class="mut">Nothing yet.</td></tr>'}
        </table></div>
        <h2>Settings</h2><div class="card"><pre>${esc(JSON.stringify(json(d?.settings, {}), null, 2))}</pre></div>`,
      ),
    );
  });

  return r;
}
