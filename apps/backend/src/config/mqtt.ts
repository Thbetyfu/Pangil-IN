import mqtt from 'mqtt';
import prisma from './db';
import { notifyDispatchers } from './socket';

let mqttClient: mqtt.MqttClient;
const activeCooldownTimers = new Map<string, NodeJS.Timeout>();

/**
 * Initializes the connection to the physical MQTT broker.
 * Subscribes to GPS and CCTV alert topics and processes messages.
 */
export const initMqtt = (): mqtt.MqttClient => {
  const brokerUrl = process.env.MQTT_BROKER_URL || 'mqtt://localhost:1883';
  console.log(`[MQTT] Connecting to MQTT broker at ${brokerUrl}...`);

  mqttClient = mqtt.connect(brokerUrl);

  mqttClient.on('connect', () => {
    console.log('[MQTT] Connected to MQTT broker successfully');
    
    // Subscribe to citizen location tracking telemetry
    mqttClient.subscribe('panggil-in/gps/+', (err) => {
      if (err) {
        console.error('[MQTT] GPS subscription failed:', err);
      } else {
        console.log('[MQTT] Subscribed to panggil-in/gps/+');
      }
    });

    // Subscribe to AI server CCTV alerts
    mqttClient.subscribe('panggil-in/cctv/alerts', (err) => {
      if (err) {
        console.error('[MQTT] CCTV alerts subscription failed:', err);
      } else {
        console.log('[MQTT] Subscribed to panggil-in/cctv/alerts');
      }
    });
  });

  mqttClient.on('message', async (topic: string, message: Buffer) => {
    try {
      const payloadString = message.toString();
      const payload = JSON.parse(payloadString);
      console.log(`[MQTT] Message received [${topic}]:`, payload);

      // Handle GPS tracking updates: panggil-in/gps/:reportId
      if (topic.startsWith('panggil-in/gps/')) {
        const reportId = topic.split('/')[2];
        const { latitude, longitude } = payload;

        if (typeof latitude === 'number' && typeof longitude === 'number') {
          // Update database with latest coordinates
          await prisma.report.update({
            where: { id: reportId },
            data: { latitude, longitude },
          });

          // Forward to police dispatchers real-time
          notifyDispatchers('gps_update', {
            reportId,
            latitude,
            longitude,
            updatedAt: new Date(),
          });
        }
      }

      // Handle CCTV alerts: panggil-in/cctv/alerts
      if (topic === 'panggil-in/cctv/alerts') {
        const { cctvId, confidence, snapshotUrl, videoClipUrl, suspectFeatureVector } = payload;

        if (cctvId && typeof confidence === 'number' && snapshotUrl) {
          // Create CCTV Alert record
          const alert = await prisma.cCTVAlert.create({
            data: {
              cctv_id: cctvId,
              confidence,
              snapshot_url: snapshotUrl,
              video_clip_url: videoClipUrl || null,
              suspect_feature_vector: suspectFeatureVector || null,
              status: 'UNVERIFIED',
            },
            include: {
              cctv: true,
            },
          });

          // Update camera fps_mode to HIGH in DB (PRD F-07)
          await prisma.cCTVCamera.update({
            where: { id: cctvId },
            data: { fps_mode: 'HIGH' }
          });

          // Notify dispatchers of the active HIGH FPS mode change
          notifyDispatchers('cctv_fps_changed', {
            id: cctvId,
            fps_mode: 'HIGH'
          });

          // Cancel existing cooldown timer if any
          if (activeCooldownTimers.has(cctvId)) {
            clearTimeout(activeCooldownTimers.get(cctvId)!);
          }

          // Register 2-minute (120 seconds) cooldown timer to reset back to LOW
          const timer = setTimeout(async () => {
            try {
              await prisma.cCTVCamera.update({
                where: { id: cctvId },
                data: { fps_mode: 'LOW' }
              });

              notifyDispatchers('cctv_fps_changed', {
                id: cctvId,
                fps_mode: 'LOW'
              });
              
              activeCooldownTimers.delete(cctvId);
              console.log(`[CCTV Adaptive] Camera ${cctvId} automatically reset to LOW after 2 minutes`);
            } catch (err) {
              console.error(`[CCTV Adaptive] Failed to reset camera ${cctvId} to LOW:`, err);
            }
          }, parseInt(process.env.CCTV_COOLDOWN_MS || '120000', 10));

          activeCooldownTimers.set(cctvId, timer);

          // Notify police dashboard
          notifyDispatchers('cctv_alert', alert);
        }
      }
    } catch (error) {
      console.error(`[MQTT] Error processing message on topic ${topic}:`, error);
    }
  });

  mqttClient.on('error', (error) => {
    console.error('[MQTT] Client connection error:', error);
  });

  return mqttClient;
};

/**
 * Returns the active MQTT client instance.
 */
export const getMqttClient = (): mqtt.MqttClient => {
  if (!mqttClient) {
    throw new Error('MQTT client has not been initialized. Call initMqtt() first.');
  }
  return mqttClient;
};
