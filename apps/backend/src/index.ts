import express from 'express';
import cors from 'cors';
import { createServer } from 'http';
import dotenv from 'dotenv';
import path from 'path';

// Load environment variables
dotenv.config();

import authRoutes from './routes/auth.routes';
import reportRoutes from './routes/report.routes';
import cctvRoutes from './routes/cctv.routes';
import patrolRoutes from './routes/patrol.routes';
import uploadsRoutes from './routes/uploads.routes';
import { initSocket } from './config/socket';
import { initMqtt } from './config/mqtt';
import { errorHandler } from './utils/errors';
import { ensureBucketExists } from './config/minio';
import prisma from './config/db';

const app = express();
const port = process.env.PORT || 3001;

// Middlewares
app.use(cors());
app.use(express.json());
app.use('/static', express.static(path.join(__dirname, '../public')));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api/cctv', cctvRoutes);
app.use('/api/patrol', patrolRoutes);
app.use('/api/uploads', uploadsRoutes);

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    // Check database connection
    await prisma.$queryRaw`SELECT 1`;
    res.status(200).json({
      status: 'healthy',
      database: 'connected',
      timestamp: new Date(),
    });
  } catch (err: any) {
    res.status(500).json({
      status: 'unhealthy',
      database: 'disconnected',
      error: err.message,
      timestamp: new Date(),
    });
  }
});

// Error handling middleware (must be registered last)
app.use(errorHandler);

// Create HTTP Server for Socket.io integration
const httpServer = createServer(app);

// Initialize Socket.io
initSocket(httpServer);

// Initialize MQTT subscription listeners
initMqtt();

// Initialize MinIO bucket (non-blocking, graceful if MinIO not running)
ensureBucketExists().catch(() => {});

// Start Server
httpServer.listen(port, () => {
  console.log(`Backend API Gateway running on port ${port}`);
});
