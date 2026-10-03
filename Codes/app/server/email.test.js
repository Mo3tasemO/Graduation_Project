import { test } from 'node:test';
import assert from 'node:assert/strict';
import { fork } from 'node:child_process';
import { once } from 'node:events';
import { DatabaseSync } from 'node:sqlite';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { isEmail } from '../shared/email.js';
import { createMailer } from './mailer.js';

test('shared email validator accepts providers and rejects malformed addresses', () => {
  for (const email of ['name@gmail.com', 'name@hotmail.com', 'name@yahoo.com', ' Person+tag@Outlook.com ', 'name@example.co.uk']) assert.equal(isEmail(email), true, email);
  for (const email of ['', null, 'name@gmail', 'name@@gmail.com', 'name @yahoo.com', '.name@gmail.com', 'name..two@hotmail.com', 'name@-gmail.com', 'name@gmail..com', 'x'.repeat(65) + '@yahoo.com', 'Name <name@gmail.com>']) assert.equal(isEmail(email), false, String(email));
});

test('mailer sends codes to all providers through one sender and validates SMTP acceptance', async () => {
  const messages = [];
  let verified = false;
  const mailer = createMailer({ SMTP_USER: 'sender@example.com', SMTP_PASS: 'test-only' }, (options) => {
    assert.equal(options.secure, true);
    return {
      verify: async () => { verified = true; },
      sendMail: async (message) => { messages.push(message); return { accepted: [message.to] }; },
    };
  });
  await mailer.verify();
  assert.equal(verified, true);
  for (const domain of ['gmail.com', 'hotmail.com', 'yahoo.com']) {
    assert.equal(await mailer.sendCode(`user@${domain}`, '123456', 'register'), true);
  }
  assert.equal(messages.length, 3);
  for (const message of messages) {
    assert.equal(message.from, 'MindSpeak <sender@example.com>');
    assert.match(message.text, /123456/);
    assert.match(message.html, /123456/);
  }
  const rejected = createMailer({ SMTP_USER: 'sender@example.com', SMTP_PASS: 'test-only', SMTP_PORT: '587' }, (options) => {
    assert.equal(options.requireTLS, true);
    return { sendMail: async () => ({ accepted: [] }) };
  });
  await assert.rejects(rejected.sendCode('user@yahoo.com', '123456', 'reset'), /did not accept/);
  await assert.rejects(createMailer({}).sendCode('user@gmail.com', '123456', 'register'), /not configured/);
});

async function startTestServer(t, dev) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'mindspeak-email-'));
  const child = fork(path.join(import.meta.dirname, 'index.js'), [], {
    env: { ...process.env, PORT: '0', MINDSPEAK_DATA_DIR: directory, DEV_SHOW_CODE: dev ? 'true' : 'false', SMTP_USER: '', SMTP_PASS: '', JWT_SECRET: 'test-secret', ADMIN_KEY: 'test-admin' },
    silent: true,
  });
  child.stdout.resume();
  child.stderr.resume();
  t.after(async () => {
    if (child.exitCode === null && child.signalCode === null) {
      const exited = once(child, 'exit');
      child.kill();
      await exited;
    }
    if (path.dirname(path.resolve(directory)) === path.resolve(os.tmpdir()) && path.basename(directory).startsWith('mindspeak-email-')) {
      fs.rmSync(directory, { recursive: true, force: true, maxRetries: 3, retryDelay: 100 });
    }
  });
  const { port } = await new Promise((resolve, reject) => {
    child.once('message', resolve);
    child.once('error', reject);
    child.once('exit', () => reject(new Error('Email test server exited')));
  });
  const call = async (route, body) => {
    const res = await fetch(`http://127.0.0.1:${port}/auth/${route}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
    return { status: res.status, ...await res.json() };
  };
  return { call, directory };
}

test('Gmail, Hotmail and Yahoo registration, verification, resend and reset flows', { timeout: 30000 }, async (t) => {
  const { call, directory } = await startTestServer(t, true);
  const db = new DatabaseSync(path.join(directory, 'mindspeak.db'));
  try {
    for (const [i, domain] of ['gmail.com', 'hotmail.com', 'yahoo.com'].entries()) {
      const email = `person@${domain}`;
      const password = 'Original1!';
      const result = await call('register', { username: `person_${i}`, email: ` ${email.toUpperCase()} `, password, phone: `0101234567${i}`, birthDate: '2000-01-01', role: 'patient' });
      assert.equal(result.status, 200);
      assert.equal(result.email, email);
      const login = await call('login', { email, password });
      assert.equal(login.error.code, 'UNVERIFIED');
      const wrong = login.error.devCode === '111111' ? '222222' : '111111';
      assert.equal((await call('verify-email', { email, code: wrong })).error.code, 'BAD_CODE');
      db.prepare("UPDATE otps SET expires=0 WHERE email=? AND purpose='register'").run(email);
      assert.equal((await call('verify-email', { email, code: login.error.devCode })).error.code, 'EXPIRED');
      const resent = await call('resend-code', { email, purpose: 'register' });
      assert.equal(resent.status, 200);
      assert.equal((await call('verify-email', { email, code: resent.devCode })).status, 200);
      assert.equal((await call('verify-email', { email, code: resent.devCode })).error.code, 'NO_CODE');
      assert.equal((await call('login', { email, password })).status, 200);
      const resetCode = await call('forgot-password', { email });
      const reset = await call('verify-reset-code', { email, code: resetCode.devCode });
      assert.equal(reset.status, 200);
      assert.equal((await call('reset-password', { email, token: reset.token, password: 'Changed2!' })).status, 200);
      assert.equal((await call('login', { email, password: 'Changed2!' })).status, 200);
    }
    assert.equal((await call('forgot-password', { email: 'bad@@yahoo.com' })).error.code, 'BAD_EMAIL');
    const unknown = await call('forgot-password', { email: 'unknown@hotmail.com' });
    assert.equal(unknown.status, 200);
    assert.equal(unknown.devCode, undefined);
  } finally { db.close(); }
});

test('real-email mode reports missing SMTP and never returns a verification code', { timeout: 15000 }, async (t) => {
  const { call } = await startTestServer(t, false);
  const result = await call('register', { username: 'real_email', email: 'user@yahoo.com', password: 'Original1!', phone: '01012345678', birthDate: '2000-01-01' });
  assert.equal(result.status, 503);
  assert.equal(result.error.code, 'MAIL_NOT_CONFIGURED');
  assert.equal(result.devCode, undefined);
  const retry = await call('resend-code', { email: 'user@yahoo.com', purpose: 'register' });
  assert.equal(retry.error.code, 'MAIL_NOT_CONFIGURED');
});
