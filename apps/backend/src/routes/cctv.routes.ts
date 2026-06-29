import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import prisma from '../config/db';
import { authenticate, requireRole } from '../middlewares/auth';
import { validate } from '../middlewares/validate';
import { NotFoundError } from '../utils/errors';
import { Role, FPSMode, CCTVStatus } from '../types/enums';
import { notifyDispatchers } from '../config/socket';

const router = Router();

// Validation schemas
const createCCTVCameraSchema = z.object({
  body: z.object({
    name: z.string().min(3),
    stream_url: z.string().url(),
    latitude: z.number().min(-90).max(90),
    longitude: z.number().min(-180).max(180),
    fps_mode: z.nativeEnum(FPSMode).optional(),
    status: z.nativeEnum(CCTVStatus).optional(),
  }),
});

const updateFPSSchema = z.object({
  body: z.object({
    fps_mode: z.nativeEnum(FPSMode),
  }),
});

// 1. Get all CCTV cameras (Police and Admins)
router.get(
  '/',
  authenticate,
  requireRole([Role.POLICE_OPERATOR, Role.SUPERADMIN]),
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const cameras = await prisma.cCTVCamera.findMany({
        orderBy: { name: 'asc' },
      });

      res.status(200).json({
        status: 'success',
        results: cameras.length,
        data: { cameras },
      });
    } catch (error) {
      next(error);
    }
  }
);

// 2. Create CCTV Camera (Superadmin only)
router.post(
  '/',
  authenticate,
  requireRole([Role.SUPERADMIN]),
  validate(createCCTVCameraSchema),
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { name, stream_url, latitude, longitude, fps_mode, status } = req.body;

      const camera = await prisma.cCTVCamera.create({
        data: {
          name,
          stream_url,
          latitude,
          longitude,
          fps_mode: fps_mode || FPSMode.LOW,
          status: status || CCTVStatus.ACTIVE,
        },
      });

      res.status(201).json({
        status: 'success',
        data: { camera },
      });
    } catch (error) {
      next(error);
    }
  }
);

// 3. Update CCTV FPS Mode (Superadmin / Police / AI triggering)
router.patch(
  '/:id/fps',
  authenticate,
  requireRole([Role.POLICE_OPERATOR, Role.SUPERADMIN]),
  validate(updateFPSSchema),
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { id } = req.params;
      const { fps_mode } = req.body;

      const camera = await prisma.cCTVCamera.findUnique({
        where: { id },
      });

      if (!camera) {
        throw new NotFoundError('CCTV Camera not found');
      }

      const updatedCamera = await prisma.cCTVCamera.update({
        where: { id },
        data: { fps_mode },
      });

      // Notify dispatch room of performance state changes
      notifyDispatchers('cctv_fps_changed', {
        id,
        name: updatedCamera.name,
        fps_mode: updatedCamera.fps_mode,
      });

      res.status(200).json({
        status: 'success',
        data: { camera: updatedCamera },
      });
    } catch (error) {
      next(error);
    }
  }
);

// 4. Get CCTV Alert logs (Police / Admins)
router.get(
  '/:id/alerts',
  authenticate,
  requireRole([Role.POLICE_OPERATOR, Role.SUPERADMIN]),
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { id } = req.params;

      const camera = await prisma.cCTVCamera.findUnique({
        where: { id },
      });

      if (!camera) {
        throw new NotFoundError('CCTV Camera not found');
      }

      const alerts = await prisma.cCTVAlert.findMany({
        where: { cctv_id: id },
        orderBy: { created_at: 'desc' },
      });

      res.status(200).json({
        status: 'success',
        results: alerts.length,
        data: { alerts },
      });
    } catch (error) {
      next(error);
    }
  }
);

export default router;
