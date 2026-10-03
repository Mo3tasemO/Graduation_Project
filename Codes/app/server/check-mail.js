import { verifyMail } from './mailer.js';

try {
  await verifyMail();
  console.log('SMTP connection and authentication passed. No email was sent. Inbox delivery must still be checked by registering and entering the emailed code.');
} catch (error) {
  console.error('Email configuration check failed:', error.code || 'NOT_READY');
  console.error('Check SMTP_HOST, SMTP_PORT, SMTP_USER and SMTP_PASS in server/.env. For Gmail, use an app password.');
  process.exitCode = 1;
}
