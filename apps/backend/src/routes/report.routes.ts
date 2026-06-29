import { Router, Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import prisma from '../config/db';
import { authenticate, requireRole } from '../middlewares/auth';
import { validate } from '../middlewares/validate';
import { BadRequestError, NotFoundError } from '../utils/errors';
import { Role, ReportType, ReportStatus, UrgencyLevel, AuthenticatedRequest } from '../types/enums';
import { notifyDispatchers, notifyNearbyCitizens, calculateDistance } from '../config/socket';

const router = Router();

// Validation schemas
const createReportSchema = z.object({
  body: z.object({
    type: z.nativeEnum(ReportType),
    latitude: z.number().min(-90).max(90),
    longitude: z.number().min(-180).max(180),
    description: z.string().optional(),
    audio_url: z.string().optional(),
    image_url: z.string().optional(),
    anti_spoofing_score: z.number().min(0).max(1).optional(),
    is_spoofed: z.boolean().optional(),
  }),
});

const updateStatusSchema = z.object({
  body: z.object({
    status: z.nativeEnum(ReportStatus),
  }),
});

const assignUnitSchema = z.object({
  body: z.object({
    assigned_unit_id: z.string().uuid(),
  }),
});

// 1. Create Report (Citizen SOS or Visual Report)
router.post(
  '/',
  authenticate,
  validate(createReportSchema),
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const reqAuth = req as AuthenticatedRequest;
      const reporterId = reqAuth.user!.id;
      const {
        type,
        latitude,
        longitude,
        description,
        audio_url,
        image_url,
        anti_spoofing_score = 1.0,
        is_spoofed = false,
      } = req.body;

      // 1. Get reporter info to evaluate reputation
      const reporter = await prisma.user.findUnique({
        where: { id: reporterId },
      });

      if (!reporter) {
        throw new NotFoundError('Reporter user not found');
      }

      let finalIsSpoofed = is_spoofed;
      let finalUrgency = UrgencyLevel.MEDIUM;

      // If user's reputation is very low, mark as low priority / spoofed
      if (reporter.reputation_score < 40) {
        finalIsSpoofed = true;
      }

      // Decrement reputation if AI or system identifies it as spoofed
      if (finalIsSpoofed) {
        await prisma.user.update({
          where: { id: reporterId },
          data: {
            reputation_score: Math.max(0, reporter.reputation_score - 15),
          },
        });
        finalUrgency = UrgencyLevel.LOW;
      } else {
        // If voice/SOS report, set urgency to high
        finalUrgency = type === ReportType.SOS_VOICE ? UrgencyLevel.HIGH : UrgencyLevel.MEDIUM;
      }

      // 2. Create the report
      const report = await prisma.report.create({
        data: {
          reporter_id: reporterId,
          type,
          status: ReportStatus.PENDING,
          urgency: finalUrgency,
          description,
          audio_url,
          image_url,
          latitude,
          longitude,
          is_spoofed: finalIsSpoofed,
          anti_spoofing_score,
        },
        include: {
          reporter: {
            select: {
              id: true,
              name: true,
              phone: true,
              reputation_score: true,
            },
          },
        },
      });

      // 3. Multi-Sensor Fusion: Automatically correlate nearest CCTV camera within 100 meters
      const cameras = await prisma.cCTVCamera.findMany({
        where: { status: 'ACTIVE' },
      });

      let nearestCamera = null;
      let minDistance = 100.0; // Max 100 meters per PRD F-06

      for (const camera of cameras) {
        const distance = calculateDistance(latitude, longitude, camera.latitude, camera.longitude);
        if (distance < minDistance) {
          minDistance = distance;
          nearestCamera = camera;
        }
      }

      // 4. Trigger Real-time Events
      // A. Alert Police Dispatchers
      notifyDispatchers('new_report', {
        ...report,
        nearestCctv: nearestCamera ? {
          id: nearestCamera.id,
          name: nearestCamera.name,
          streamUrl: nearestCamera.stream_url,
          distance: Math.round(minDistance),
        } : null,
      });

      // B. Trigger Proximity Alerts (Community Alert) if valid (not spoofed)
      if (!finalIsSpoofed) {
        notifyNearbyCitizens(latitude, longitude, 500, reporterId);
      }

      res.status(201).json({
        status: 'success',
        data: {
          report,
          nearestCctv: nearestCamera,
        },
      });
    } catch (error) {
      next(error);
    }
  }
);

// 2. List Reports
router.get(
  '/',
  authenticate,
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const reqAuth = req as AuthenticatedRequest;
      const userRole = reqAuth.user!.role;
      const userId = reqAuth.user!.id;

      let reports;

      if (userRole === Role.POLICE_OPERATOR || userRole === Role.SUPERADMIN) {
        // Police see everything
        reports = await prisma.report.findMany({
          include: {
            reporter: {
              select: { id: true, name: true, phone: true, reputation_score: true },
            },
            assigned_unit: true,
          },
          orderBy: { created_at: 'desc' },
        });
      } else {
        // Citizen gets their own reports, or public non-spoofed reports within 2km
        const { lat, lng } = req.query;
        
        if (lat && lng) {
          const userLat = parseFloat(lat as string);
          const userLng = parseFloat(lng as string);

          const allPublicReports = await prisma.report.findMany({
            where: {
              is_spoofed: false,
              status: { in: [ReportStatus.PENDING, ReportStatus.VALIDATED, ReportStatus.ON_PROCESS] },
            },
            include: {
              reporter: {
                select: { id: true, name: true, reputation_score: true },
              },
            },
          });

          // Filter by distance (2km)
          reports = allPublicReports.filter((r) => {
            const distance = calculateDistance(userLat, userLng, r.latitude, r.longitude);
            return distance <= 2000; // 2km radius
          });
        } else {
          // Fallback to own reports
          reports = await prisma.report.findMany({
            where: { reporter_id: userId },
            orderBy: { created_at: 'desc' },
          });
        }
      }

      res.status(200).json({
        status: 'success',
        results: reports.length,
        data: { reports },
      });
    } catch (error) {
      next(error);
    }
  }
);

// 3. Get Report by ID
router.get(
  '/:id',
  authenticate,
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { id } = req.params;
      const reqAuth = req as AuthenticatedRequest;
      const user = reqAuth.user!;

      const report = await prisma.report.findUnique({
        where: { id },
        include: {
          reporter: {
            select: { id: true, name: true, phone: true, reputation_score: true },
          },
          assigned_unit: true,
        },
      });

      if (!report) {
        throw new NotFoundError('Report not found');
      }

      // Restrict citizens to their own reports or public ones
      if (user.role === Role.CITIZEN && report.reporter_id !== user.id && report.is_spoofed) {
        throw new BadRequestError('Access denied');
      }

      res.status(200).json({
        status: 'success',
        data: { report },
      });
    } catch (error) {
      next(error);
    }
  }
);

// 4. Update Report Status (Police / Admin)
router.patch(
  '/:id/status',
  authenticate,
  requireRole([Role.POLICE_OPERATOR, Role.SUPERADMIN]),
  validate(updateStatusSchema),
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { id } = req.params;
      const { status } = req.body;

      const report = await prisma.report.findUnique({
        where: { id },
      });

      if (!report) {
        throw new NotFoundError('Report not found');
      }

      const updatedReport = await prisma.report.update({
        where: { id },
        data: { status },
      });

      // Broadcast update to police rooms
      notifyDispatchers('report_updated', updatedReport);

      res.status(200).json({
        status: 'success',
        data: { report: updatedReport },
      });
    } catch (error) {
      next(error);
    }
  }
);

// 5. Assign Patrol Unit (Police / Admin)
router.patch(
  '/:id/assign',
  authenticate,
  requireRole([Role.POLICE_OPERATOR, Role.SUPERADMIN]),
  validate(assignUnitSchema),
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { id } = req.params;
      const { assigned_unit_id } = req.body;

      const [report, unit] = await Promise.all([
        prisma.report.findUnique({ where: { id } }),
        prisma.patrolUnit.findUnique({ where: { id: assigned_unit_id } }),
      ]);

      if (!report) {
        throw new NotFoundError('Report not found');
      }

      if (!unit) {
        throw new NotFoundError('Patrol unit not found');
      }

      const updatedReport = await prisma.report.update({
        where: { id },
        data: {
          assigned_unit_id,
          status: ReportStatus.ON_PROCESS,
        },
      });

      // Update unit status
      await prisma.patrolUnit.update({
        where: { id: assigned_unit_id },
        data: { status: 'ON_DUTY' },
      });

      // Broadcast assignment
      notifyDispatchers('report_assigned', {
        reportId: id,
        unit,
      });

      res.status(200).json({
        status: 'success',
        data: { report: updatedReport },
      });
    } catch (error) {
      next(error);
    }
  }
);

// 6. Test Endpoint to Publish Mock MQTT message
router.post(
  '/test/mock-mqtt',
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { topic, payload } = req.body;
      const { getMqttClient } = require('../config/mqtt');
      getMqttClient().publish(topic, JSON.stringify(payload));
      res.status(200).json({
        status: 'success',
        message: `Published mock MQTT event on topic ${topic}`,
      });
    } catch (error) {
      next(error);
    }
  }
);

// 7. BLE Mesh Relay Endpoint (PRD F-03 BLE Mesh Tracking)
const bleRelaySchema = z.object({
  body: z.object({
    beacon_id: z.string(),
    latitude: z.number().min(-90).max(90),
    longitude: z.number().min(-180).max(180),
    relay_user_id: z.string().optional(),
  }),
});

router.post(
  '/ble-relay',
  validate(bleRelaySchema),
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      const { beacon_id, latitude, longitude, relay_user_id } = req.body;

      // Find active report matching beacon_id as report ID or reporter ID
      let report = await prisma.report.findFirst({
        where: {
          OR: [
            { id: beacon_id },
            { reporter_id: beacon_id }
          ],
          status: { in: [ReportStatus.PENDING, ReportStatus.VALIDATED, 'ON_PROCESS'] }
        },
        orderBy: {
          created_at: 'desc'
        }
      });

      if (!report) {
        throw new NotFoundError('No active SOS report found for this beacon ID');
      }

      // Update coordinates
      const updatedReport = await prisma.report.update({
        where: { id: report.id },
        data: { latitude, longitude }
      });

      // Notify dispatchers with BLE mesh relayer info
      notifyDispatchers('gps_update', {
        reportId: report.id,
        latitude,
        longitude,
        isBleRelay: true,
        relayName: relay_user_id ? `Relay User (${relay_user_id.substring(0, 8)})` : 'Relay Komunitas Anonim',
        updatedAt: new Date()
      });

      res.status(200).json({
        status: 'success',
        data: {
          reportId: report.id,
          latitude,
          longitude,
          isBleRelay: true
        }
      });
    } catch (error) {
      next(error);
    }
  }
);

export default router;
