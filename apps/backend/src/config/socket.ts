import { Server as HttpServer } from 'http';
import { Server, Socket } from 'socket.io';
import { Role } from '../types/enums';

let io: Server;

// Track active connections with their locations and roles
interface ActiveSocket {
  socketId: string;
  userId: string;
  role: Role;
  latitude?: number;
  longitude?: number;
}

const activeSockets = new Map<string, ActiveSocket>();

export const initSocket = (server: HttpServer): Server => {
  io = new Server(server, {
    cors: {
      origin: '*',
      methods: ['GET', 'POST'],
    },
  });

  io.on('connection', (socket: Socket) => {
    console.log(`Socket connected: ${socket.id}`);

    // Register user details on connection
    socket.on('register', (data: { userId: string; role: Role }) => {
      activeSockets.set(socket.id, {
        socketId: socket.id,
        userId: data.userId,
        role: data.role,
      });
      
      // If police operator, join the dispatcher room
      if (data.role === Role.POLICE_OPERATOR || data.role === Role.SUPERADMIN) {
        socket.join('dispatchers');
        console.log(`Socket ${socket.id} joined dispatchers room`);
      }
    });

    // Update coordinates for proximity notifications (Citizen Riding/Active mode)
    socket.on('update_location', async (data: { latitude?: number; longitude?: number; encrypted_payload?: string }) => {
      const active = activeSockets.get(socket.id);
      if (active) {
        let lat = data.latitude;
        let lng = data.longitude;

        if (data.encrypted_payload) {
          try {
            const { decryptCoordinates } = require('../utils/crypto');
            const decrypted = decryptCoordinates(data.encrypted_payload);
            lat = decrypted.latitude;
            lng = decrypted.longitude;
            console.log(`[Socket] Decrypted location update: (${lat}, ${lng})`);
          } catch (err: any) {
            console.error('[Socket] Failed to decrypt update_location:', err.message);
          }
        }

        if (lat !== undefined && lng !== undefined) {
          active.latitude = lat;
          active.longitude = lng;
          activeSockets.set(socket.id, active);
        }

        // If the socket belongs to a citizen, check if they have any active SOS report
        if (active.role === Role.CITIZEN) {
          try {
            const prisma = require('./db').default;
            const activeReport = await prisma.report.findFirst({
              where: {
                reporter_id: active.userId,
                status: 'PENDING',
              },
              orderBy: {
                created_at: 'desc',
              },
            });

            if (activeReport) {
              const { getMqttClient } = require('./mqtt');
              const mqttClient = getMqttClient();
              if (mqttClient) {
                const topic = `panggil-in/gps/${activeReport.id}`;
                let mqttPayload;
                if (data.encrypted_payload) {
                  mqttPayload = { encrypted_payload: data.encrypted_payload };
                } else if (lat !== undefined && lng !== undefined) {
                  const { encryptCoordinates } = require('../utils/crypto');
                  mqttPayload = { encrypted_payload: encryptCoordinates(lat, lng) };
                }

                if (mqttPayload) {
                  mqttClient.publish(topic, JSON.stringify(mqttPayload));
                  console.log(`[Socket->MQTT] Bridge: Published ENCRYPTED location to ${topic}`);
                }
              }
            }
          } catch (err) {
            console.error('[Socket->MQTT] Error bridging location to MQTT:', err);
          }
        }
      }
    });

    socket.on('disconnect', () => {
      console.log(`Socket disconnected: ${socket.id}`);
      activeSockets.delete(socket.id);
    });
  });

  return io;
};

export const getIo = (): Server => {
  if (!io) {
    throw new Error('Socket.io not initialized');
  }
  return io;
};

// Haversine formula to calculate distance in meters
export const calculateDistance = (lat1: number, lon1: number, lat2: number, lon2: number): number => {
  const R = 6371000; // Earth radius in meters
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
};

// Emit real-time alert to police dispatch room
export const notifyDispatchers = (eventName: string, data: any): void => {
  if (io) {
    io.to('dispatchers').emit(eventName, data);
  }
};

// Send anonymous community alert to citizens within a specific radius (e.g. 500m)
// Why: We combine Socket.io (for online users) AND FCM push (for background/killed app users)
// to ensure no nearby citizen misses a community alert (PRD F-02).
export const notifyNearbyCitizens = async (
  originLat: number,
  originLng: number,
  radiusMeters: number,
  excludeUserId: string
): Promise<void> => {
  if (!io) return;

  const alertMessage = `Darurat! Sinyal bahaya aktif di dekat Anda. Harap waspada dan merapat bersama kelompok jika aman.`;

  // 1. Notify online citizens via Socket.io (immediate, for active sessions)
  const onlineSocketIds = new Set<string>();
  activeSockets.forEach((client) => {
    if (client.role === Role.CITIZEN && client.userId !== excludeUserId && client.latitude && client.longitude) {
      const distance = calculateDistance(originLat, originLng, client.latitude, client.longitude);
      if (distance <= radiusMeters) {
        onlineSocketIds.add(client.userId);
        io.to(client.socketId).emit('community_alert', {
          message: `Sinyal Bahaya Terdeteksi di Radius ${Math.round(distance)} meter dari Posisi Anda. Harap berhati-hati dan lakukan intervensi massal jika memungkinkan.`,
          distance,
          timestamp: new Date(),
        });
      }
    }
  });

  // 2. Send FCM push to offline citizens who have registered their FCM token
  // Why async background: We don't want FCM latency to block the Socket.io response.
  setImmediate(async () => {
    try {
      const { sendBatchPushNotifications } = require('./firebase');
      const prisma = require('./db').default;

      // Query all CITIZEN users who have an FCM token and are NOT already notified via socket
      // Note: We cannot do geofencing server-side for offline users (no known location),
      // so we send to ALL citizens with FCM tokens except the SOS reporter.
      // In production, last-known-location from Redis/DB can be used for precise filtering.
      const citizensWithFcm = await prisma.user.findMany({
        where: {
          role: Role.CITIZEN,
          id: { not: excludeUserId },
          fcm_token: { not: null },
          NOT: { id: { in: Array.from(onlineSocketIds) } }, // Skip already notified via socket
        },
        select: { fcm_token: true },
      });

      const tokens = citizensWithFcm
        .map((u: { fcm_token: string | null }) => u.fcm_token)
        .filter((t: string | null): t is string => t !== null);

      if (tokens.length > 0) {
        await sendBatchPushNotifications(
          tokens,
          'Sinyal Bahaya Terdekat!',
          alertMessage,
          { type: 'community_alert', timestamp: new Date().toISOString() }
        );
      }
    } catch (err) {
      console.error('[FCM Community Alert] Background push failed:', err);
    }
  });
};

