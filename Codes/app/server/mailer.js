import nodemailer from 'nodemailer';

const { SMTP_HOST = 'smtp.gmail.com', SMTP_PORT = '465', SMTP_USER, SMTP_PASS, MAIL_FROM } = process.env;

export const mailConfigured = Boolean(SMTP_USER && SMTP_PASS);

const transport = mailConfigured
  ? nodemailer.createTransport({
      host: SMTP_HOST,
      port: Number(SMTP_PORT),
      secure: Number(SMTP_PORT) === 465,
      auth: { user: SMTP_USER, pass: SMTP_PASS },
    })
  : null;

const TEXT = {
  register: { subject: 'Verify your MindSpeak email', lead: 'Use this code to verify your email and finish creating your account.' },
  reset: { subject: 'Reset your MindSpeak password', lead: 'Use this code to confirm it is really you and reset your password.' },
};

/** Sends the 6-digit code. Returns true if a real email left the server. */
export async function sendCode(to, code, purpose) {
  const t = TEXT[purpose];
  if (!transport) {
    console.log(`[mail] SMTP not configured, code for ${to} (${purpose}): ${code}`);
    return false;
  }
  await transport.sendMail({
    from: MAIL_FROM || `MindSpeak <${SMTP_USER}>`,
    to,
    subject: t.subject,
    text: `${t.lead}\n\nYour code: ${code}\n\nIt expires in 10 minutes. If you did not ask for this, ignore this email.`,
    html: `<div style="font-family:Arial,sans-serif;max-width:420px;margin:auto;padding:24px">
      <h2 style="color:#2563EB;margin:0 0 8px">MindSpeak</h2>
      <p style="color:#334155">${t.lead}</p>
      <div style="font-size:34px;letter-spacing:8px;font-weight:700;background:#EFF6FF;color:#1D4ED8;text-align:center;padding:16px;border-radius:12px">${code}</div>
      <p style="color:#64748B;font-size:13px">This code expires in 10 minutes. If you did not request it, you can ignore this email.</p>
    </div>`,
  });
  return true;
}
