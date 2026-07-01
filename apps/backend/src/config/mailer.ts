import nodemailer from 'nodemailer';

// Why lazy singleton: SMTP may not be configured in local dev.
// We log a warning instead of crashing on startup.
let transporter: nodemailer.Transporter | null = null;

const getTransporter = (): nodemailer.Transporter | null => {
  if (transporter) return transporter;

  const host = process.env.SMTP_HOST;
  const user = process.env.SMTP_USER;

  if (!host || !user || user.includes('your_email')) {
    console.warn('[SMTP] Not configured — email OTP will be skipped');
    return null;
  }

  transporter = nodemailer.createTransport({
    host,
    port: parseInt(process.env.SMTP_PORT || '587'),
    secure: process.env.SMTP_SECURE === 'true',
    auth: {
      user,
      pass: process.env.SMTP_PASS,
    },
  });

  return transporter;
};

/**
 * Send OTP via email.
 * Returns true if sent successfully, false if SMTP not configured or failed.
 */
export const sendOtpEmail = async (
  toEmail: string,
  toName: string,
  otpCode: string
): Promise<boolean> => {
  const t = getTransporter();
  if (!t) return false;

  try {
    await t.sendMail({
      from: process.env.SMTP_FROM || 'Panggil-In <noreply@panggil.in>',
      to: toEmail,
      subject: 'Kode OTP Verifikasi Panggil-In SIGAP',
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; background: #0F1219; color: #fff; padding: 32px; border-radius: 12px;">
          <h2 style="color: #FF1744; margin-bottom: 8px;">Kode Verifikasi SIGAP</h2>
          <p style="color: #aaa; font-size: 14px;">Halo, <strong>${toName}</strong>.</p>
          <p style="color: #ccc; font-size: 14px;">Gunakan kode OTP berikut untuk masuk ke aplikasi SIGAP Police:</p>
          <div style="background: #1E2638; border: 2px solid #FF1744; border-radius: 8px; padding: 20px; text-align: center; margin: 24px 0;">
            <span style="font-size: 36px; font-weight: bold; letter-spacing: 12px; color: #FF1744;">${otpCode}</span>
          </div>
          <p style="color: #888; font-size: 12px;">Kode ini berlaku selama <strong>5 menit</strong> dan hanya boleh digunakan sekali.</p>
          <p style="color: #888; font-size: 12px;">Jika Anda tidak meminta kode ini, abaikan email ini segera.</p>
          <hr style="border-color: #1E2638; margin: 20px 0;">
          <p style="color: #555; font-size: 11px;">Panggil-In — Sistem Deteksi & Penanganan Begal Cerdas</p>
        </div>
      `,
    });
    console.log(`[SMTP] OTP email sent to ${toEmail}`);
    return true;
  } catch (err) {
    console.error('[SMTP] Failed to send OTP email:', err);
    return false;
  }
};
