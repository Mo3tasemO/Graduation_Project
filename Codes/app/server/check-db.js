import { db, DATABASE_PATH } from './db.js';
import { checkDatabase } from './database-checks.js';

try {
  const result = checkDatabase(db);
  console.log(JSON.stringify({ database: DATABASE_PATH, ...result }, null, 2));
  process.exitCode = result.ok && (!process.argv.includes('--strict') || !result.warnings.length) ? 0 : 1;
} finally {
  db.close();
}
