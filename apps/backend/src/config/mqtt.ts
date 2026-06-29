import { EventEmitter } from 'events';
import prisma from './db';
import { notifyDispatchers } from './socket';

class MockMqttClient extends EventEmitter {
  public subscribe(topic: string, callback?: (err?: Error) => void) {
    console.log(`[Mock MQTT] Subscribed to topic: ${topic}`);
    if (callback) callback();
  }

  public publish(topic: string, message: string | Buffer, callback?: (err?: Error) => void) {
    // Simulate receiving a message after a brief delay
    setTimeout(() => {
      this.emit('message', topic, Buffer.from(message));
    }, 50);
    if (callback) callback();
  }
}

const mockMqtt = new MockMqttClient();

export const initMqtt = (): MockMqttClient => {
  console.log('[Mock MQTT] Initializing Mock MQTT Broker in-memory...');

  // Setup message listener
  mockMqtt.on('message', async (topic: string, message: Buffer) => {
    try {
      const payloadString = message.toString();
      const payload = JSON.parse(payloadString);
      console.log(`[Mock MQTT] Msg Received [${topic}]:`, payload);

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
          // Create CCTV Alert
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

          // Notify police dashboard
          notifyDispatchers('cctv_alert', alert);
        }
      }
    } catch (error) {
      console.error(`[Mock MQTT] Error processing message on topic ${topic}:`, error);
    }
  });

  return mockMqtt;
};

export const getMqttClient = (): MockMqttClient => {
  return mockMqtt;
};
