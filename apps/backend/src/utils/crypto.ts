import crypto from 'crypto';

const AES_SECRET_KEY = process.env.AES_SECRET_KEY || 'panggilin_super_secret_32_bytes_';
const IV = Buffer.alloc(16, 0);

/**
 * Decrypts a Base64 encoded AES-256-CBC string into latitude and longitude coordinates.
 * Ensures the telemetry payload is secure and conforms to the user's PRD specifications.
 */
export const decryptCoordinates = (encryptedBase64: string): { latitude: number; longitude: number } => {
  try {
    const decipher = crypto.createDecipheriv('aes-256-cbc', Buffer.from(AES_SECRET_KEY), IV);
    let decrypted = decipher.update(encryptedBase64, 'base64', 'utf8');
    decrypted += decipher.final('utf8');
    
    const parsed = JSON.parse(decrypted);
    if (typeof parsed.latitude !== 'number' || typeof parsed.longitude !== 'number') {
      throw new Error('Decrypted coordinates are not valid numbers');
    }
    
    return {
      latitude: parsed.latitude,
      longitude: parsed.longitude,
    };
  } catch (error: any) {
    console.error('[Crypto Helper] Decryption failed:', error.message);
    throw new Error(`Coordinates decryption failed: ${error.message}`);
  }
};

/**
 * Encrypts coordinates into a Base64 string for testing or mocking purposes.
 */
export const encryptCoordinates = (latitude: number, longitude: number): string => {
  const plainText = JSON.stringify({ latitude, longitude });
  const cipher = crypto.createCipheriv('aes-256-cbc', Buffer.from(AES_SECRET_KEY), IV);
  let encrypted = cipher.update(plainText, 'utf8', 'base64');
  encrypted += cipher.final('base64');
  return encrypted;
};
