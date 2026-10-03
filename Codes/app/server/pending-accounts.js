export const PENDING_ACCOUNT_TTL_MS = 10 * 60 * 1000;
export const PENDING_CLEANUP_INTERVAL_MS = 15 * 1000;

/** Account age is measured from its original UTC creation time, not the last OTP. */
export function cleanupExpiredPendingAccounts(db, now = Date.now()) {
  const cutoff = new Date(now - PENDING_ACCOUNT_TTL_MS).toISOString().slice(0, 19).replace('T', ' ');
  const expired = 'SELECT email FROM users WHERE verified=0 AND created_at<=?';
  if (!db.prepare(`${expired} LIMIT 1`).get(cutoff)) return 0;
  db.exec('BEGIN IMMEDIATE');
  try {
    db.prepare(`DELETE FROM otps WHERE email IN (${expired})`).run(cutoff);
    db.prepare(`DELETE FROM reset_tokens WHERE email IN (${expired})`).run(cutoff);
    // Role records, profile data and biometric devices cascade through foreign keys.
    const { changes } = db.prepare('DELETE FROM users WHERE verified=0 AND created_at<=?').run(cutoff);
    db.exec('COMMIT');
    return changes;
  } catch (error) {
    db.exec('ROLLBACK');
    throw error;
  }
}

export function startPendingAccountCleanup(db, { intervalMs = PENDING_CLEANUP_INTERVAL_MS } = {}) {
  cleanupExpiredPendingAccounts(db); // also catches accounts that expired while offline
  const timer = setInterval(() => {
    try {
      cleanupExpiredPendingAccounts(db);
    } catch (error) {
      console.error('[pending accounts] Cleanup failed:', error.code || 'DATABASE_ERROR');
    }
  }, intervalMs);
  timer.unref();
  return () => clearInterval(timer);
}
