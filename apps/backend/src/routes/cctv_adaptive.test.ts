import test from 'node:test';
import assert from 'node:assert';
import EventEmitter from 'events';

// Mock DB, Socket config, and mqtt
const dbPath = require.resolve('../config/db');
const socketPath = require.resolve('../config/socket');
const mqttLibPath = require.resolve('mqtt');

// Setup environment variable for test
process.env.CCTV_COOLDOWN_MS = '20';

const updatedCameras: any[] = [];
const createdAlerts: any[] = [];

const mockPrisma = {
  cCTVAlert: {
    create: async (args: any) => {
      const alert = {
        id: 'mock-alert-1',
        cctv_id: args.data.cctv_id,
        confidence: args.data.confidence,
        snapshot_url: args.data.snapshot_url,
        video_clip_url: args.data.video_clip_url,
        suspect_feature_vector: args.data.suspect_feature_vector,
        status: args.data.status,
        cctv: { id: args.data.cctv_id, name: 'CCTV Dago 01' },
      };
      createdAlerts.push(alert);
      return alert;
    },
  },
  cCTVCamera: {
    update: async (args: any) => {
      const updateData = {
        id: args.where.id,
        fps_mode: args.data.fps_mode,
      };
      updatedCameras.push(updateData);
      return { id: args.where.id, name: 'CCTV Dago 01', fps_mode: args.data.fps_mode };
    },
  },
};

const lastDispatchedEvents: any[] = [];
const mockSocket = {
  notifyDispatchers: (eventName: string, data: any) => {
    lastDispatchedEvents.push({ eventName, data });
  },
};

// Mock emitter for MQTT client
class MockMqttClient extends EventEmitter {
  subscribe(topic: string, cb: any) {
    if (cb) cb(null);
  }
}
const mockMqttEmitter = new MockMqttClient();

const mockMqtt = {
  connect: () => {
    return mockMqttEmitter;
  },
};

// Fill require cache
require.cache[dbPath] = {
  id: dbPath,
  filename: dbPath,
  loaded: true,
  exports: {
    default: mockPrisma,
    prisma: mockPrisma,
    ...mockPrisma,
  },
  paths: [],
} as any;

require.cache[socketPath] = {
  id: socketPath,
  filename: socketPath,
  loaded: true,
  exports: mockSocket,
  paths: [],
} as any;

require.cache[mqttLibPath] = {
  id: mqttLibPath,
  filename: mqttLibPath,
  loaded: true,
  exports: mockMqtt,
  paths: [],
} as any;

// Import target file after require caching is established
import { initMqtt } from '../config/mqtt';

test('CCTV Adaptive FPS Escalation and Cooldown Reset (PRD F-07)', async () => {
  // Clear lists
  updatedCameras.length = 0;
  createdAlerts.length = 0;
  lastDispatchedEvents.length = 0;

  // Initialize
  initMqtt();

  // Simulate receipt of CCTV Anomaly Alert via MQTT
  const alertPayload = {
    cctvId: 'cctv-uuid-dago-11',
    confidence: 0.92,
    snapshotUrl: 'https://storage.panggil.in/cctv_snapshots/alert_1.jpg',
    videoClipUrl: 'https://storage.panggil.in/cctv_clips/alert_clip_1.mp4',
    suspectFeatureVector: 'helm_merah_jaket_hitam',
  };

  // Emit connect
  mockMqttEmitter.emit('connect');
  
  // Emit message alert
  mockMqttEmitter.emit(
    'message',
    'panggil-in/cctv/alerts',
    Buffer.from(JSON.stringify(alertPayload))
  );

  // Allow async tasks (prisma create/update) to run
  await new Promise((resolve) => setTimeout(resolve, 10));

  // Verify Escalation to HIGH:
  // 1. Alert created
  assert.strictEqual(createdAlerts.length, 1);
  assert.strictEqual(createdAlerts[0].cctv_id, 'cctv-uuid-dago-11');

  // 2. Camera updated to HIGH
  const firstCameraUpdate = updatedCameras.find(
    (c) => c.id === 'cctv-uuid-dago-11' && c.fps_mode === 'HIGH'
  );
  assert.ok(firstCameraUpdate);

  // 3. Socket event cctv_fps_changed emitted with HIGH
  const firstSocketEvent = lastDispatchedEvents.find(
    (e) => e.eventName === 'cctv_fps_changed' && e.data.fps_mode === 'HIGH'
  );
  assert.ok(firstSocketEvent);

  // Sleep to trigger cooldown (set to 20ms)
  await new Promise((resolve) => setTimeout(resolve, 30));

  // Verify Reset to LOW:
  // 1. Camera updated to LOW
  const secondCameraUpdate = updatedCameras.find(
    (c) => c.id === 'cctv-uuid-dago-11' && c.fps_mode === 'LOW'
  );
  assert.ok(secondCameraUpdate);

  // 2. Socket event cctv_fps_changed emitted with LOW
  const secondSocketEvent = lastDispatchedEvents.find(
    (e) => e.eventName === 'cctv_fps_changed' && e.data.fps_mode === 'LOW'
  );
  assert.ok(secondSocketEvent);
});
