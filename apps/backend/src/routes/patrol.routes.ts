import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import prisma from '../config/db';
import { authenticate, requireRole } from '../middlewares/auth';
import { validate } from '../middlewares/validate';
import { NotFoundError } from '../utils/errors';
import { Role, PatrolStatus } from '../types/enums';
import { notifyDispatchers } from '../config/socket';

const router = Router();

// Validation schemas
const createPatrolUnitSchema = z.object({
  body: z.object({
    name: z.string().min(3),
    latitude: z.number().min(-90).max(90),
    longitude: z.number().min(-180).max(180),
    status: z.nativeEnum(PatrolStatus).optional(),
    phone: z.string().min(8),
  }),
});

const updateLocationSchema = z.object({
  body: z.object({
    latitude: z.number().min(-90).max(90),
    longitude: z.number().min(-180).max(180),
  }),
});

const updateStatusSchema = z.object({
  body: z.object({
    status: z.nativeEnum(PatrolStatus),
  }),
});

// 1. Get all patrol units (Police & Admin)
router.get(
  '/',
  authenticate,
  requireRole([Role.POLICE_OPERATOR, Role.SUPERADMIN]),
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const units = await prisma.patrolUnit.findMany({
        orderBy: { name: 'asc' },
      });

      res.status(200).json({
        status: 'success',
        results: units.length,
        data: { units },
      });
    } catch (error) {
      next(error);
    }
  }
);

// 2. Create Patrol Unit (Police & Admin)
router.post(
  '/',
  authenticate,
  requireRole([Role.POLICE_OPERATOR, Role.SUPERADMIN]),
  validate(createPatrolUnitSchema),
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { name, latitude, longitude, status, phone } = req.body;

      const unit = await prisma.patrolUnit.create({
        data: {
          name,
          latitude,
          longitude,
          status: status || PatrolStatus.AVAILABLE,
          phone,
        },
      });

      res.status(201).json({
        status: 'success',
        data: { unit },
      });
    } catch (error) {
      next(error);
    }
  }
);

// 3. Update Patrol Unit Location (Police & Admin & Unit self-telemetry)
router.patch(
  '/:id/location',
  authenticate,
  requireRole([Role.POLICE_OPERATOR, Role.SUPERADMIN]),
  validate(updateLocationSchema),
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { id } = req.params;
      const { latitude, longitude } = req.body;

      const unit = await prisma.patrolUnit.findUnique({
        where: { id },
      });

      if (!unit) {
        throw new NotFoundError('Patrol Unit not found');
      }

      const updatedUnit = await prisma.patrolUnit.update({
        where: { id },
        data: { latitude, longitude },
      });

      // Broadcast location change to dispatcher room
      notifyDispatchers('patrol_location_updated', {
        id,
        name: updatedUnit.name,
        latitude: updatedUnit.latitude,
        longitude: updatedUnit.longitude,
      });

      res.status(200).json({
        status: 'success',
        data: { unit: updatedUnit },
      });
    } catch (error) {
      next(error);
    }
  }
);

// 4. Update Patrol Unit Status (Police & Admin)
router.patch(
  '/:id/status',
  authenticate,
  requireRole([Role.POLICE_OPERATOR, Role.SUPERADMIN]),
  validate(updateStatusSchema),
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { id } = req.params;
      const { status } = req.body;

      const unit = await prisma.patrolUnit.findUnique({
        where: { id },
      });

      if (!unit) {
        throw new NotFoundError('Patrol Unit not found');
      }

      const updatedUnit = await prisma.patrolUnit.update({
        where: { id },
        data: { status },
      });

      // Broadcast status change
      notifyDispatchers('patrol_status_updated', {
        id,
        name: updatedUnit.name,
        status: updatedUnit.status,
      });

      res.status(200).json({
        status: 'success',
        data: { unit: updatedUnit },
      });
    } catch (error) {
      next(error);
    }
  }
);

export default router;
