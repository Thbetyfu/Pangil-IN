import { Router, Request, Response, NextFunction } from 'express';
import multer from 'multer';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { authenticate } from '../middlewares/auth';
import { uploadFileToMinio } from '../config/minio';
import { BadRequestError } from '../utils/errors';

const router = Router();

// Why in-memory storage: We immediately stream the buffer to MinIO.
// Storing to disk is unnecessary and would require cleanup.
const storage = multer.memoryStorage();

const imageUpload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB max for images
  fileFilter: (_req, file, cb) => {
    const allowed = ['.jpg', '.jpeg', '.png', '.webp'];
    const ext = path.extname(file.originalname).toLowerCase();
    if (allowed.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error('Only JPEG, PNG, and WebP images are allowed'));
    }
  },
});

const audioUpload = multer({
  storage,
  limits: { fileSize: 30 * 1024 * 1024 }, // 30MB max for audio (max 30s SOS recording)
  fileFilter: (_req, file, cb) => {
    const allowed = ['.mp3', '.wav', '.m4a', '.aac'];
    const ext = path.extname(file.originalname).toLowerCase();
    if (allowed.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error('Only MP3, WAV, M4A, and AAC audio files are allowed'));
    }
  },
});

/**
 * POST /api/uploads/image
 * Upload a visual report evidence photo to MinIO/S3.
 * Returns the public URL that can be stored in Report.image_url.
 */
router.post(
  '/image',
  authenticate,
  imageUpload.single('file'),
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.file) {
        throw new BadRequestError('No image file provided in the request');
      }

      const ext = path.extname(req.file.originalname).toLowerCase();
      const objectName = `images/${uuidv4()}${ext}`;

      const publicUrl = await uploadFileToMinio(
        objectName,
        req.file.buffer,
        req.file.mimetype
      );

      if (!publicUrl) {
        // MinIO not configured — return a placeholder URL for dev mode
        res.status(200).json({
          status: 'success',
          data: {
            url: `http://localhost:3001/static/placeholder_image.jpg`,
            storage: 'local_fallback',
            message: 'MinIO not configured. Using local static fallback.',
          },
        });
        return;
      }

      res.status(200).json({
        status: 'success',
        data: {
          url: publicUrl,
          object_name: objectName,
          storage: 'minio',
        },
      });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * POST /api/uploads/audio
 * Upload a voice SOS recording to MinIO/S3.
 * Returns the public URL that can be stored in Report.audio_url.
 */
router.post(
  '/audio',
  authenticate,
  audioUpload.single('file'),
  async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.file) {
        throw new BadRequestError('No audio file provided in the request');
      }

      const ext = path.extname(req.file.originalname).toLowerCase();
      const objectName = `audio/${uuidv4()}${ext}`;

      const publicUrl = await uploadFileToMinio(
        objectName,
        req.file.buffer,
        req.file.mimetype
      );

      if (!publicUrl) {
        res.status(200).json({
          status: 'success',
          data: {
            url: `http://localhost:3001/static/placeholder_audio.wav`,
            storage: 'local_fallback',
            message: 'MinIO not configured. Using local static fallback.',
          },
        });
        return;
      }

      res.status(200).json({
        status: 'success',
        data: {
          url: publicUrl,
          object_name: objectName,
          storage: 'minio',
        },
      });
    } catch (error) {
      next(error);
    }
  }
);

export default router;
