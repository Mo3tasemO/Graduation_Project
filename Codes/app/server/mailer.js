import nodemailer from 'nodemailer';

const TEXT = {
  register: { subject: 'Verify your MindSpeak email', lead: 'Use this code to verify your email and finish creating your account.' },
  reset: { subject: 'Reset your MindSpeak password', lead: 'Use this code to confirm it is really you and reset your password.' },
};

export function createMailer(config = process.env, transportFactory = nodemailer.createTransport) {
  const { SMTP_HOST = 'smtp.gmail.com', SMTP_PORT = '465', SMTP_USER, SMTP_PASS, MAIL_FROM } = config;
  const configured = Boolean(SMTP_USER?.trim() && SMTP_PASS?.trim());
  const transport = configured ? transportFactory({
    host: SMTP_HOST,
    port: Number(SMTP_PORT),
    secure: Number(SMTP_PORT) === 465,
    requireTLS: Number(SMTP_PORT) !== 465,
    auth: { user: SMTP_USER, pass: SMTP_PASS },
    connectionTimeout: 5000,
    greetingTimeout: 5000,
    socketTimeout: 10000,
    dnsTimeout: 5000,
  }) : null;

  /** True means the SMTP server accepted the recipient; inbox arrival is not guaranteed. */
  const sendCode = async (to, code, purpose) => {
  const t = TEXT[purpose];
  const expiry = purpose === 'register'
    ? 'Verify within 10 minutes of creating your account. Resending a code does not extend this deadline; unverified accounts are removed automatically.'
    : 'This code expires in 10 minutes.';
  if (!transport) {
    if (config.DEV_SHOW_CODE !== 'true') throw new Error('SMTP is not configured');
    console.log(`[mail] DEV MODE, code for ${to} (${purpose}): ${code}`);
    return false;
  }
  const result = await transport.sendMail({
    from: MAIL_FROM || `MindSpeak <${SMTP_USER}>`,
    to,
    subject: t.subject,
    text: `${t.lead}\n\nYour code: ${code}\n\n${expiry} If you did not ask for this, ignore this email.`,
    html: `<div style="font-family:Arial,sans-serif;max-width:420px;margin:auto;padding:24px">
      <h2 style="color:#2563EB;margin:0 0 8px">MindSpeak</h2>
      <p style="color:#334155">${t.lead}</p>
      <div style="font-size:34px;letter-spacing:8px;font-weight:700;background:#EFF6FF;color:#1D4ED8;text-align:center;padding:16px;border-radius:12px">${code}</div>
      <p style="color:#64748B;font-size:13px">${expiry} If you did not request it, you can ignore this email.</p>
    </div>`,
  });
  if (!result.accepted?.some((address) => String(address).toLowerCase() === to.toLowerCase())) {
    throw new Error('SMTP server did not accept the recipient');
  }
  return true;
  };
  return {
    configured,
    sendCode,
    async verify() {
      if (!transport) throw new Error('Set SMTP_USER and SMTP_PASS in server/.env first.');
      await transport.verify();
    },
  };
}

const mailer = createMailer();
export const mailConfigured = mailer.configured;
export const sendCode = mailer.sendCode;
export const verifyMail = mailer.verify;
