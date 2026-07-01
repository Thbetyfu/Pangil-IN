import { Router, Request, Response, NextFunction } from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import prisma from '../config/db';
import { validate } from '../middlewares/validate';
import { BadRequestError, UnauthorizedError } from '../utils/errors';
import { Role, AuthenticatedRequest } from '../types/enums';
import { apiTokenLimiter } from '../middlewares/rateLimit';
import { authenticate } from '../middlewares/auth';
import { sendOtpEmail } from '../config/mailer';

const router = Router();
const JWT_SECRET = process.env.JWT_SECRET || 'panggil_in_super_secret_key_change_me_in_production';

// Validation schemas
const registerSchema = z.object({
  body: z.object({
    email: z.string().email('Invalid email address'),
    password: z.string().min(6, 'Password must be at least 6 characters'),
    name: z.string().min(2, 'Name must be at least 2 characters'),
    phone: z.string().min(8, 'Phone number must be at least 8 digits'),
    role: z.nativeEnum(Role).optional(),
  }),
});

const loginSchema = z.object({
  body: z.object({
    email: z.string().email('Invalid email address'),
    password: z.string().min(6, 'Password is too short'),
  }),
});

const otpSendSchema = z.object({
  body: z.object({
    email: z.string().email('Invalid email address'),
  }),
});

const otpVerifySchema = z.object({
  body: z.object({
    email: z.string().email('Invalid email address'),
    code: z.string().length(6, 'OTP code must be exactly 6 digits').regex(/^\d+$/, 'OTP must be numeric'),
  }),
});

const fcmTokenSchema = z.object({
  body: z.object({
    fcm_token: z.string().min(10, 'Invalid FCM token'),
  }),
});

// Registration handler
router.post(
  '/register',
  validate(registerSchema),
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { email, password, name, phone, role } = req.body;

      const existingUser = await prisma.user.findFirst({
        where: { OR: [{ email }, { phone }] },
      });

      if (existingUser) {
        throw new BadRequestError('Email or Phone number already registered');
      }

      const salt = await bcrypt.genSalt(10);
      const hashedPassword = await bcrypt.hash(password, salt);

      const user = await prisma.user.create({
        data: { email, password: hashedPassword, name, phone, role: role || Role.CITIZEN },
      });

      const token = jwt.sign(
        { id: user.id, email: user.email, role: user.role },
        JWT_SECRET,
        { expiresIn: '12h' }
      );

      res.status(201).json({
        status: 'success',
        data: {
          token,
          user: {
            id: user.id, email: user.email, name: user.name, phone: user.phone,
            role: user.role, reputation_score: user.reputation_score, riding_mode: user.riding_mode,
          },
        },
      });
    } catch (error) {
      next(error);
    }
  }
);

// Login handler
// Why: Business logic update to bypass OTP for Citizens ($0 SMS policy)
// but mandate OTP for Police Operators and Superadmins (PRD Section 6 Security).
router.post(
  '/login',
  apiTokenLimiter,
  validate(loginSchema),
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { email, password } = req.body;

      const user = await prisma.user.findUnique({ where: { email } });
      if (!user) throw new UnauthorizedError('Invalid email or password');

      const isMatch = await bcrypt.compare(password, user.password);
      if (!isMatch) throw new UnauthorizedError('Invalid email or password');

      // If user is a Police Operator or Superadmin, enforce 2FA OTP
      if (user.role === Role.POLICE_OPERATOR || user.role === Role.SUPERADMIN) {
        const rawOtp = Math.floor(100000 + Math.random() * 900000).toString();
        const salt = await bcrypt.genSalt(10);
        const hashedOtp = await bcrypt.hash(rawOtp, salt);
        const otpExpires = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes

        await prisma.user.update({
          where: { id: user.id },
          data: { otp_code: hashedOtp, otp_expires: otpExpires },
        });

        const emailSent = await sendOtpEmail(user.email, user.name, rawOtp);

        let smsSent = false;
        const twilioSid = process.env.TWILIO_ACCOUNT_SID;
        if (twilioSid && !twilioSid.includes('your_twilio')) {
          try {
            const twilio = require('twilio')(twilioSid, process.env.TWILIO_AUTH_TOKEN);
            await twilio.messages.create({
              body: `[Panggil-In SIGAP] Kode OTP Anda: ${rawOtp}. Berlaku 5 menit. Jangan bagikan ke siapapun.`,
              from: process.env.TWILIO_PHONE_NUMBER,
              to: user.phone,
            });
            smsSent = true;
            console.log(`[Twilio] OTP SMS sent to ${user.phone}`);
          } catch (twilioErr) {
            console.warn('[Twilio] SMS sending failed:', twilioErr);
          }
        }

        if (!emailSent && !smsSent) {
          console.log(`[DEV] OTP for ${email}: ${rawOtp} (SMTP/Twilio not configured)`);
        }

        res.status(200).json({
          status: 'success',
          requires_2fa: true,
          message: 'Autentikasi dua faktor diperlukan. Kode OTP telah dikirimkan ke email/SMS Anda.',
          ...(process.env.NODE_ENV !== 'production' && {
            debug: {
              email_sent: emailSent,
              sms_sent: smsSent,
              otp_dev: !emailSent && !smsSent ? rawOtp : undefined,
            },
          }),
        });
        return;
      }

      // Citizens bypass OTP completely and receive the JWT immediately
      const token = jwt.sign(
        { id: user.id, email: user.email, role: user.role },
        JWT_SECRET,
        { expiresIn: '12h' }
      );

      res.status(200).json({
        status: 'success',
        data: {
          token,
          user: {
            id: user.id,
            email: user.email,
            name: user.name,
            phone: user.phone,
            role: user.role,
            reputation_score: user.reputation_score,
            riding_mode: user.riding_mode,
          },
        },
      });
    } catch (error) {
      next(error);
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 2FA OTP: Send OTP via email + SMS (POLICE / ADMIN ONLY)
// Why: Block Citizens from requesting OTPs to avoid SMS Gateway billing leaks.
// ─────────────────────────────────────────────────────────────────────────────
router.post(
  '/otp/send',
  apiTokenLimiter,
  validate(otpSendSchema),
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { email } = req.body;

      const user = await prisma.user.findUnique({ where: { email } });
      if (!user) {
        // Generic response to prevent email enumeration
        res.status(200).json({ status: 'success', message: 'Jika email terdaftar, kode OTP telah dikirimkan.' });
        return;
      }

      // Enforce: Citizens cannot request OTPs
      if (user.role === Role.CITIZEN) {
        throw new BadRequestError('Warga (Citizen) tidak memerlukan verifikasi OTP. Silakan masuk langsung menggunakan email & password.');
      }

      const rawOtp = Math.floor(100000 + Math.random() * 900000).toString();
      const salt = await bcrypt.genSalt(10);
      const hashedOtp = await bcrypt.hash(rawOtp, salt);
      const otpExpires = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes

      await prisma.user.update({
        where: { id: user.id },
        data: { otp_code: hashedOtp, otp_expires: otpExpires },
      });

      const emailSent = await sendOtpEmail(user.email, user.name, rawOtp);

      // SMS via Twilio if configured
      let smsSent = false;
      const twilioSid = process.env.TWILIO_ACCOUNT_SID;
      if (twilioSid && !twilioSid.includes('your_twilio')) {
        try {
          const twilio = require('twilio')(twilioSid, process.env.TWILIO_AUTH_TOKEN);
          await twilio.messages.create({
            body: `[Panggil-In SIGAP] Kode OTP Anda: ${rawOtp}. Berlaku 5 menit. Jangan bagikan ke siapapun.`,
            from: process.env.TWILIO_PHONE_NUMBER,
            to: user.phone,
          });
          smsSent = true;
          console.log(`[Twilio] OTP SMS sent to ${user.phone}`);
        } catch (twilioErr) {
          console.warn('[Twilio] SMS sending failed:', twilioErr);
        }
      }

      if (!emailSent && !smsSent) {
        console.log(`[DEV] OTP for ${email}: ${rawOtp} (SMTP/Twilio not configured)`);
      }

      res.status(200).json({
        status: 'success',
        message: 'Jika email terdaftar, kode OTP telah dikirimkan.',
        ...(process.env.NODE_ENV !== 'production' && {
          debug: {
            email_sent: emailSent,
            sms_sent: smsSent,
            otp_dev: !emailSent && !smsSent ? rawOtp : undefined,
          },
        }),
      });
    } catch (error) {
      next(error);
    }
  }
);

// 2FA OTP: Verify OTP and issue JWT (POLICE / ADMIN ONLY)
router.post(
  '/otp/verify',
  apiTokenLimiter,
  validate(otpVerifySchema),
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { email, code } = req.body;

      const user = await prisma.user.findUnique({ where: { email } });
      if (!user) {
        throw new UnauthorizedError('Kode OTP tidak valid atau sudah kadaluarsa.');
      }

      // Block Citizens from verification endpoint
      if (user.role === Role.CITIZEN) {
        throw new BadRequestError('Warga (Citizen) tidak memerlukan verifikasi OTP. Silakan masuk langsung.');
      }

      if (!user.otp_code || !user.otp_expires) {
        throw new UnauthorizedError('Kode OTP tidak valid atau sudah kadaluarsa.');
      }

      // Check expiry first to avoid unnecessary bcrypt comparison
      if (new Date() > user.otp_expires) {
        await prisma.user.update({
          where: { id: user.id },
          data: { otp_code: null, otp_expires: null },
        });
        throw new UnauthorizedError('Kode OTP sudah kadaluarsa. Silakan minta kode baru.');
      }

      const isValid = await bcrypt.compare(code, user.otp_code);
      if (!isValid) {
        throw new UnauthorizedError('Kode OTP tidak valid. Periksa kembali kode Anda.');
      }

      // Clear OTP after successful verification (single-use)
      await prisma.user.update({
        where: { id: user.id },
        data: { otp_code: null, otp_expires: null },
      });

      const token = jwt.sign(
        { id: user.id, email: user.email, role: user.role },
        JWT_SECRET,
        { expiresIn: '12h' }
      );

      console.log(`[2FA] OTP verified for ${email}`);

      res.status(200).json({
        status: 'success',
        message: 'Verifikasi 2FA berhasil.',
        data: {
          token,
          user: {
            id: user.id,
            email: user.email,
            name: user.name,
            phone: user.phone,
            role: user.role,
            reputation_score: user.reputation_score,
          },
        },
      });
    } catch (error) {
      next(error);
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// FCM Token Registration — Save device token for background push notifications (PRD F-02)
// Why: Socket.io community_alert only works for online users.
// FCM ensures background/killed app still receives proximity alerts.
// ─────────────────────────────────────────────────────────────────────────────
router.post(
  '/fcm-token',
  authenticate,
  validate(fcmTokenSchema),
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const reqAuth = req as AuthenticatedRequest;
      const userId = reqAuth.user!.id;
      const { fcm_token } = req.body;

      await prisma.user.update({
        where: { id: userId },
        data: { fcm_token },
      });

      console.log(`[FCM] Token registered for user ${userId.substring(0, 8)}...`);

      res.status(200).json({ status: 'success', message: 'FCM token registered successfully' });
    } catch (error) {
      next(error);
    }
  }
);

export default router;
