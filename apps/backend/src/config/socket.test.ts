import test from 'node:test';
import assert from 'node:assert';
import path from 'path';

// Resolve exact paths to mock modules using require.resolve
const dbPath = require.resolve('./db');
const mqttPath = require.resolve('./mqtt');

// Setup mock objects in Node.js require cache
const mockPrisma = {
  report: {
    findFirst: async (args: any) => {
      // Mock finding an active pending report for the citizen
      return {
        id: 'mock-report-uuid-abc',
        citizen_id: args.where.citizen_id,
        status: 'PENDING',
      };
    }
  }
};

const mockMqttClient = {
  publish: (topic: string, message: string) => {
    mockMqttClient.lastPublishedTopic = topic;
    mockMqttClient.lastPublishedPayload = JSON.parse(message);
  },
  lastPublishedTopic: '',
  lastPublishedPayload: null as any,
};

require.cache[dbPath] = {
  id: dbPath,
  filename: dbPath,
  loaded: true,
  exports: {
    default: mockPrisma,
  },
  paths: [],
} as any;

require.cache[mqttPath] = {
  id: mqttPath,
  filename: mqttPath,
  loaded: true,
  exports: {
    getMqttClient: () => mockMqttClient,
  },
  paths: [],
} as any;

// Import socket module after caching mocks
import { initSocket } from './socket';
import { Role } from '../types/enums';

test('Socket-to-MQTT Bridge works correctly when citizen updates location', async () => {
  const events = new Map<string, Function>();
  
  const mockSocket = {
    id: 'socket-citizen-1',
    join(room: string) {},
    on(event: string, callback: Function) {
      events.set(event, callback);
    }
  } as any;

  // Mock HTTP Server
  const mockServer = {} as any;
  
  // Initialize Socket.io
  const io = initSocket(mockServer);

  // Retrieve connection listener and trigger it manually
  const connectionListener = (io as any).listeners('connection')[0];
  assert.ok(connectionListener, 'Connection listener should be registered');
  connectionListener(mockSocket);

  // Trigger 'register' event to store active socket info
  const registerHandler = events.get('register');
  assert.ok(registerHandler, 'Register handler should be registered');
  registerHandler({ userId: 'citizen-user-123', role: Role.CITIZEN });

  // Trigger 'update_location' event
  const updateLocationHandler = events.get('update_location');
  assert.ok(updateLocationHandler, 'Update location handler should be registered');
  
  await updateLocationHandler({ latitude: -6.90344, longitude: 107.61872 });

  // Assert that coordinates were successfully bridged and published to Mosquitto MQTT
  assert.strictEqual(mockMqttClient.lastPublishedTopic, 'panggil-in/gps/mock-report-uuid-abc');
  assert.deepStrictEqual(mockMqttClient.lastPublishedPayload, {
    latitude: -6.90344,
    longitude: 107.61872,
  });
});
