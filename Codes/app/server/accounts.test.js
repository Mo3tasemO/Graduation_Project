import { test } from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { fork } from 'node:child_process';
import { once } from 'node:events';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { migrateAccounts, normalizePhone } from './account-schema.js';

test('phone normalization covers formatting and local/international Egyptian numbers', () => {
  for (const phone of ['01012345678', '+20 101 234 5678', '00201012345678', '201012345678', '(010) 1234-5678']) {
    assert.equal(normalizePhone(phone), '201012345678');
  }
  for (const phone of ['', '1234', 'hello01012345678', '++201012345678', '1'.repeat(16), null, 1012345678]) {
    assert.equal(normalizePhone(phone), null);
  }
});

test('migration preserves legacy accounts and blocks new duplicates at database level', () => {
  const db = new DatabaseSync(':memory:');
  try {
    db.exec(`PRAGMA foreign_keys=ON;
      CREATE TABLE users(id INTEGER PRIMARY KEY, patient_id TEXT UNIQUE, phone TEXT, verified INTEGER);
      INSERT INTO users VALUES(1, 'p1', '01012345678', 1), (2, 'p2', '+201012345678', 1);
    `);
    migrateAccounts(db);
    migrateAccounts(db); // restart is safe
    assert.equal(db.prepare('SELECT COUNT(*) AS n FROM users').get().n, 2);
    assert.equal(db.prepare('SELECT role FROM users WHERE id=1').get().role, 'patient');
    assert.throws(() => db.prepare('INSERT INTO users(patient_id, phone, phone_key) VALUES(?,?,?)').run('p3', '01012345678', '201012345678'), /PHONE_TAKEN/);
    db.prepare('UPDATE users SET phone_key=? WHERE id=2').run('201112345678');
    assert.throws(() => db.prepare('UPDATE users SET phone_key=? WHERE id=2').run('201012345678'), /PHONE_TAKEN/);
    assert.throws(() => db.prepare('UPDATE users SET role=?, linked_patient_id=? WHERE id=2').run('caregiver', 'missing'), /BAD_PATIENT_ID/);
  } finally { db.close(); }
});

test('account API enforces phones, caregiver links, and password reuse', { timeout: 30000 }, async (t) => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'mindspeak-accounts-'));
  const childOptions = {
    env: { ...process.env, PORT: '0', MINDSPEAK_DATA_DIR: directory, DEV_SHOW_CODE: 'true', SMTP_USER: '', SMTP_PASS: '', JWT_SECRET: 'isolated-test-secret', ADMIN_KEY: 'isolated-admin-key' },
    silent: true,
  };
  let child = fork(path.join(import.meta.dirname, 'index.js'), [], childOptions);
  child.stdout.resume();
  let errors = '';
  child.stderr.on('data', (data) => { errors += data; });
  t.after(async () => {
    if (child.exitCode === null && child.signalCode === null) {
      const exited = once(child, 'exit');
      child.kill();
      await exited;
    }
    // Only remove the exact temporary directory this test created.
    if (path.dirname(path.resolve(directory)) === path.resolve(os.tmpdir()) && path.basename(directory).startsWith('mindspeak-accounts-')) {
      fs.rmSync(directory, { recursive: true, force: true, maxRetries: 3, retryDelay: 100 });
    }
  });
  let { port } = await new Promise((resolve, reject) => {
    child.once('message', resolve);
    child.once('error', reject);
    child.once('exit', () => reject(new Error(`Test server exited: ${errors}`)));
  });
  const call = async (url, body, token, method = 'POST') => {
    const res = await fetch(`http://127.0.0.1:${port}${url}`, { method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) }, body: body === undefined ? undefined : JSON.stringify(body) });
    return { status: res.status, ...await res.json() };
  };
  const password = 'Original1!';
  const account = (username, phone, extra = {}) => ({ username, email: `${username}@gmail.com`, phone, password, birthDate: '2000-01-01', role: 'patient', ...extra });
  const register = async (input, verify = true) => {
    const result = await call('/auth/register', input);
    assert.equal(result.status, 200, JSON.stringify(result));
    if (verify) assert.equal((await call('/auth/verify-email', { email: input.email, code: result.devCode })).status, 200);
    return result;
  };
  const patient = account('patient_one', '01012345678');
  await register(patient);
  const login = await call('/auth/login', patient);
  assert.equal(login.user.role, 'patient');
  assert.equal(login.user.linkedPatientId, '');

  await t.test('duplicate phone spelling and simultaneous registrations', async () => {
    for (const phone of ['01012345678', '+20 101 234 5678', '00201012345678']) {
      const result = await call('/auth/register', account('duplicate_user', phone));
      assert.equal(result.status, 409);
      assert.equal(result.error.code, 'PHONE_TAKEN');
    }
    const pending = account('pending_user', '01112345678');
    await register(pending, false);
    await register(pending, false); // retry same pending account is supported
    assert.equal((await call('/auth/register', account('other_pending', pending.phone))).error.code, 'PHONE_TAKEN');
    const results = await Promise.all(['race_one', 'race_two'].map((name) => call('/auth/register', account(name, '01212345678'))));
    assert.deepEqual(results.map((r) => r.status).sort(), [200, 409]);
    assert.equal(results.find((r) => r.status === 409).error.code, 'PHONE_TAKEN');
  });

  let caregiverLogin;
  await t.test('caregiver requires a verified patient and keeps its role and link', async () => {
    const caregiver = account('caregiver_one', '01512345678', { role: 'caregiver' });
    assert.equal((await call('/auth/register', caregiver)).error.code, 'BAD_PATIENT_ID');
    assert.equal((await call('/auth/register', { ...caregiver, linkedPatientId: 'missing' })).error.code, 'BAD_PATIENT_ID');
    const inspect = new DatabaseSync(path.join(directory, 'mindspeak.db'), { readOnly: true });
    let pendingId;
    try { pendingId = inspect.prepare("SELECT patient_id FROM users WHERE username='pending_user'").get().patient_id; }
    finally { inspect.close(); }
    assert.equal((await call('/auth/register', { ...caregiver, linkedPatientId: pendingId })).error.code, 'BAD_PATIENT_ID');
    await register({ ...caregiver, linkedPatientId: login.user.id });
    caregiverLogin = await call('/auth/login', caregiver);
    assert.equal(caregiverLogin.user.role, 'caregiver');
    assert.equal(caregiverLogin.user.linkedPatientId, login.user.id);
    assert.equal((await call('/auth/login', { ...caregiver, role: 'patient' })).error.code, 'WRONG_ROLE');
    assert.equal((await call('/auth/register', account('caregiver_two', '01011111111', { role: 'caregiver', linkedPatientId: caregiverLogin.user.id }))).error.code, 'BAD_PATIENT_ID');
    assert.equal((await call('/auth/register', account('bad_role', '01011111111', { role: 'admin' }))).error.code, 'BAD_ROLE');
  });

  await t.test('profile edits enforce uniqueness and background sync cannot alter identity', async () => {
    const token = caregiverLogin.token;
    assert.equal((await call('/me/profile', { phone: '+201012345678' }, token, 'PUT')).error.code, 'PHONE_TAKEN');
    assert.equal((await call('/me/profile', { phone: '' }, token, 'PUT')).error.code, 'BAD_PHONE');
    assert.equal((await call('/me/profile', { phone: '01099999999' }, token, 'PUT')).user.phone, '01099999999');
    assert.equal((await call('/me/data', { profile: { role: 'patient', linkedPatientId: 'fake', phone: patient.phone, condition: 'saved' } }, token, 'PUT')).status, 200);
    const result = await call('/me/data', undefined, token, 'GET');
    assert.equal(result.user.phone, '01099999999');
    assert.equal(result.user.role, 'caregiver');
    assert.equal(result.user.linkedPatientId, login.user.id);
    assert.equal(result.data.profile.condition, 'saved');
    assert.equal(result.data.profile.role, undefined);
  });

  await t.test('separate SQL records persist on disk and admin lists are protected', async () => {
    const inspect = new DatabaseSync(path.join(directory, 'mindspeak.db'), { readOnly: true });
    try {
      assert.equal(inspect.prepare('SELECT COUNT(*) AS n FROM patients').get().n, 3);
      const caregiver = inspect.prepare('SELECT * FROM caregiver_records').get();
      assert.equal(caregiver.caregiver_id, caregiverLogin.user.id);
      assert.equal(caregiver.patient_id, login.user.id);
      assert.equal(caregiver.phone, '01099999999');
      assert.equal(inspect.prepare('PRAGMA foreign_key_check').all().length, 0);
    } finally { inspect.close(); }
    for (const role of ['patients', 'caregivers']) {
      const unauthorized = await fetch(`http://127.0.0.1:${port}/admin/api/${role}`);
      assert.equal(unauthorized.status, 401);
      const res = await fetch(`http://127.0.0.1:${port}/admin/api/${role}`, { headers: { 'x-admin-key': 'isolated-admin-key' } });
      assert.equal(res.status, 200);
      const records = await res.json();
      assert.equal(records.length, role === 'patients' ? 3 : 1);
      assert.equal(records.some((r) => 'password_hash' in r), false);
      const page = await fetch(`http://127.0.0.1:${port}/admin/${role}?key=isolated-admin-key`);
      assert.equal(page.status, 200);
      assert.match(await page.text(), new RegExp(`${role} table`));
    }
  });

  await t.test('same password is rejected, retry succeeds, reset token is single-use', async () => {
    const email = patient.email;
    const device = await call('/me/biometric/enable', {}, login.token);
    const code = await call('/auth/forgot-password', { email });
    const reset = await call('/auth/verify-reset-code', { email, code: code.devCode });
    assert.equal((await call('/auth/reset-password', { email, token: 'invalid', password })).error.code, 'BAD_TOKEN');
    const same = await call('/auth/reset-password', { email, token: reset.token, password });
    assert.equal(same.error.code, 'SAME_PASSWORD');
    assert.match(same.error.message, /same as your old password/);
    assert.equal((await call('/auth/login', patient)).status, 200);
    const next = { email, token: reset.token, password: 'Different2!' };
    assert.equal((await call('/auth/reset-password', next)).status, 200);
    assert.equal((await call('/auth/reset-password', { ...next, password: 'Another3!' })).error.code, 'BAD_TOKEN');
    assert.equal((await call('/auth/login', patient)).status, 401);
    assert.equal((await call('/auth/login', next)).status, 200);
    assert.equal((await call('/auth/login-biometric', { email, deviceToken: device.deviceToken })).status, 401);
  });

  await t.test('server restart retains credentials, role tables, patient links and saved data', async () => {
    const exited = once(child, 'exit');
    child.kill();
    await exited;
    child = fork(path.join(import.meta.dirname, 'index.js'), [], childOptions);
    child.stdout.resume();
    child.stderr.resume();
    ({ port } = await new Promise((resolve, reject) => {
      child.once('message', resolve);
      child.once('error', reject);
      child.once('exit', () => reject(new Error('Restarted server exited early')));
    }));
    assert.equal((await call('/auth/login', { email: patient.email, password: 'Different2!' })).status, 200);
    const caregiver = await call('/auth/login', { email: 'caregiver_one@gmail.com', password, role: 'caregiver' });
    assert.equal(caregiver.user.linkedPatientId, login.user.id);
    assert.equal(caregiver.user.phone, '01099999999');
    assert.equal(caregiver.data.profile.condition, 'saved');
    assert.equal(fs.existsSync(path.join(directory, 'backups')), false); // no migration repeats on restart
  });

  await t.test('expired accounts disappear from admin, cannot verify or resend, and can register again', async () => {
    const input = account('expiry_user', '01055555555');
    const pending = await register(input, false);
    const inspect = new DatabaseSync(path.join(directory, 'mindspeak.db'));
    try {
      inspect.prepare("UPDATE users SET created_at=datetime('now','-11 minutes') WHERE email=?").run(input.email);
      const res = await fetch(`http://127.0.0.1:${port}/admin/api/users`, { headers: { 'x-admin-key': 'isolated-admin-key' } });
      assert.equal((await res.json()).some((u) => u.email === input.email), false);
      assert.equal((await call('/auth/verify-email', { email: input.email, code: pending.devCode })).error.code, 'ACCOUNT_EXPIRED');
      assert.equal((await call('/auth/resend-code', { email: input.email, purpose: 'register' })).error.code, 'ACCOUNT_EXPIRED');
      assert.equal(inspect.prepare('SELECT 1 FROM otps WHERE email=?').get(input.email), undefined);
      await register(input);
      assert.equal((await call('/auth/login', input)).status, 200);
    } finally { inspect.close(); }
  });
});
