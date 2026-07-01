import * as Minio from 'minio';

// Why lazy singleton: MinIO may not be running in all dev environments.
// We initialize the client only when first needed, and log a warning instead of crashing.
let minioClient: Minio.Client | null = null;

const BUCKET = process.env.MINIO_BUCKET_NAME || 'panggilin-media';

export const getMinioClient = (): Minio.Client | null => {
  if (minioClient) return minioClient;

  const endpoint = process.env.MINIO_ENDPOINT;
  if (!endpoint || endpoint === 'localhost' && !process.env.MINIO_ACCESS_KEY) {
    return null;
  }

  try {
    minioClient = new Minio.Client({
      endPoint: process.env.MINIO_ENDPOINT || 'localhost',
      port: parseInt(process.env.MINIO_PORT || '9000'),
      useSSL: process.env.MINIO_USE_SSL === 'true',
      accessKey: process.env.MINIO_ACCESS_KEY || 'minioadmin',
      secretKey: process.env.MINIO_SECRET_KEY || 'minioadmin',
    });
    console.log('[MinIO] Client initialized');
  } catch (err) {
    console.warn('[MinIO] Failed to initialize client:', err);
    return null;
  }

  return minioClient;
};

// Ensure the media bucket exists (idempotent, safe to call on startup)
export const ensureBucketExists = async (): Promise<void> => {
  const client = getMinioClient();
  if (!client) {
    console.warn('[MinIO] Skipping bucket check — client not configured');
    return;
  }

  try {
    const exists = await client.bucketExists(BUCKET);
    if (!exists) {
      await client.makeBucket(BUCKET, 'us-east-1');
      console.log(`[MinIO] Bucket '${BUCKET}' created`);
    } else {
      console.log(`[MinIO] Bucket '${BUCKET}' already exists`);
    }
  } catch (err) {
    console.warn('[MinIO] Cannot verify bucket:', err);
  }
};

// Upload a buffer to MinIO and return the public URL
export const uploadFileToMinio = async (
  objectName: string,
  buffer: Buffer,
  contentType: string
): Promise<string | null> => {
  const client = getMinioClient();
  if (!client) return null;

  try {
    await client.putObject(BUCKET, objectName, buffer, buffer.length, {
      'Content-Type': contentType,
    });

    // Construct URL — in production, use a CDN or presigned URL
    const endpoint = process.env.MINIO_ENDPOINT || 'localhost';
    const port = process.env.MINIO_PORT || '9000';
    const ssl = process.env.MINIO_USE_SSL === 'true';
    const protocol = ssl ? 'https' : 'http';

    return `${protocol}://${endpoint}:${port}/${BUCKET}/${objectName}`;
  } catch (err) {
    console.error('[MinIO] Upload failed:', err);
    return null;
  }
};
