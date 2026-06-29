import { Router, Request, Response, NextFunction } from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { z } from 'zod';
import prisma from '../config/db';
import { validate } from '../middlewares/validate';
import { BadRequestError, UnauthorizedError } from '../utils/errors';
import { Role } from '../types/enums';

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

// Registration handler
router.post(
  '/register',
  validate(registerSchema),
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { email, password, name, phone, role } = req.body;

      // Check if email or phone is already registered
      const existingUser = await prisma.user.findFirst({
        where: {
          OR: [{ email }, { phone }],
        },
      });

      if (existingUser) {
        throw new BadRequestError('Email or Phone number already registered');
      }

      // Hash password
      const salt = await bcrypt.genSalt(10);
      const hashedPassword = await bcrypt.hash(password, salt);

      // Create user
      const user = await prisma.user.create({
        data: {
          email,
          password: hashedPassword,
          name,
          phone,
          role: role || Role.CITIZEN,
        },
      });

      // Generate JWT token
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

// Login handler
router.post(
  '/login',
  validate(loginSchema),
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { email, password } = req.body;

      const user = await prisma.user.findUnique({
        where: { email },
      });

      if (!user) {
        throw new UnauthorizedError('Invalid email or password');
      }

      const isMatch = await bcrypt.compare(password, user.password);
      if (!isMatch) {
        throw new UnauthorizedError('Invalid email or password');
      }

      // Generate JWT token
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

export default router;
