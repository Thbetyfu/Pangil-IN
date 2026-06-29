import test from 'node:test';
import assert from 'node:assert';

// Mock DB and Socket config
const dbPath = require.resolve('../config/db');
const socketPath = require.resolve('../config/socket');

const mockPrisma = {
  report: {
    findFirst: async (args: any) => {
      return {
        id: 'mock-report-uuid-xyz',
        reporter_id: 'mock-reporter-id-abc',
        status: 'PENDING',
        latitude: -6.91,
        longitude: 107.60,
      };
    },
    update: async (args: any) => {
      return {
        id: args.where.id,
        latitude: args.data.latitude,
        longitude: args.data.longitude,
      };
    },
  },
};

const lastDispatchedEvents: any[] = [];
const mockSocket = {
  notifyDispatchers: (eventName: string, data: any) => {
    lastDispatchedEvents.push({ eventName, data });
  },
  notifyNearbyCitizens: () => {},
};

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

const authPath = require.resolve('../middlewares/auth');
const mockAuth = {
  authenticate: (req: any, res: any, next: any) => {
    req.user = { id: 'mock-reporter-id-abc', role: 'CITIZEN' };
    next();
  },
  requireRole: (roles: any) => (req: any, res: any, next: any) => next(),
};
require.cache[authPath] = {
  id: authPath,
  filename: authPath,
  loaded: true,
  exports: mockAuth,
  paths: [],
} as any;

// Import Express and register report routes dynamically to prevent hoisting
const express = require('express');
const reportRouter = require('./report.routes').default;

test('BLE Mesh Relay Endpoint (POST /api/reports/ble-relay) works correctly', async () => {
  const app = express();
  app.use(express.json());
  app.use('/api/reports', reportRouter);

  // Start temporary server
  const server = app.listen(0);
  const address = server.address() as any;
  const port = address.port;

  try {
    const response = await fetch(`http://localhost:${port}/api/reports/ble-relay`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        beacon_id: 'mock-reporter-id-abc',
        latitude: -6.90344,
        longitude: 107.61872,
        relay_user_id: 'relay-user-uuid-12345678',
      }),
    });

    assert.strictEqual(response.status, 200);
    const data = (await response.json()) as any;
    assert.strictEqual(data.status, 'success');
    assert.strictEqual(data.data.reportId, 'mock-report-uuid-xyz');
    assert.strictEqual(data.data.latitude, -6.90344);
    assert.strictEqual(data.data.longitude, 107.61872);

    // Verify Socket event was dispatched
    const event = lastDispatchedEvents.find(e => e.eventName === 'gps_update');
    assert.ok(event, 'gps_update event should be dispatched');
    assert.strictEqual(event.data.reportId, 'mock-report-uuid-xyz');
    assert.strictEqual(event.data.isBleRelay, true);
    assert.strictEqual(event.data.relayName, 'Relay User (relay-us)');

    // Verify Heatmap Endpoint (GET /api/reports/heatmap) (PRD F-07/F-03 Offline Cache)
    const heatmapResponse = await fetch(`http://localhost:${port}/api/reports/heatmap`);
    assert.strictEqual(heatmapResponse.status, 200);
    const heatmapData = (await heatmapResponse.json()) as any;
    assert.strictEqual(heatmapData.status, 'success');
    assert.strictEqual(heatmapData.data.points.length, 3);
    assert.strictEqual(heatmapData.data.points[0].areaName, 'Simpang Dago');
  } finally {
    server.close();
  }
});
