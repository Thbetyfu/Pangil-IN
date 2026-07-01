import { App, getApps, initializeApp, cert } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';

// Why lazy singleton with graceful degradation:
// Firebase Admin requires service account credentials that aren't available in all dev environments.
// We initialize only when credentials are present and valid, logging a warning otherwise.
let firebaseApp: App | null = null;

const initFirebase = (): App | null => {
  if (firebaseApp) return firebaseApp;

  const existingApps = getApps();
  if (existingApps.length > 0) {
    firebaseApp = existingApps[0];
    return firebaseApp;
  }

  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY;

  if (!projectId || projectId === 'your_firebase_project_id' || !clientEmail || !privateKey) {
    console.warn('[Firebase] Not configured — FCM push notifications will be skipped');
    return null;
  }

  try {
    firebaseApp = initializeApp({
      credential: cert({
        projectId,
        clientEmail,
        // Handle escaped newlines from .env file
        privateKey: privateKey.replace(/\\n/g, '\n'),
      }),
    });
    console.log('[Firebase] Admin SDK initialized successfully');
    return firebaseApp;
  } catch (err) {
    console.error('[Firebase] Failed to initialize Admin SDK:', err);
    return null;
  }
};

/**
 * Send a push notification to a single FCM token.
 * Returns true if sent, false if Firebase not configured or failed.
 */
export const sendPushNotification = async (
  fcmToken: string,
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<boolean> => {
  const app = initFirebase();
  if (!app) return false;

  try {
    await getMessaging(app).send({
      token: fcmToken,
      notification: { title, body },
      data: data || {},
      android: {
        priority: 'high',
        notification: {
          sound: 'panggilin_alert', // Custom alert tone (must be in Android res/raw)
          channelId: 'panggilin_community_alert',
          icon: 'ic_alert',
          color: '#FF1744',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'panggilin_alert.caf',
            badge: 1,
          },
        },
      },
    });
    console.log(`[FCM] Push notification sent to token: ${fcmToken.substring(0, 20)}...`);
    return true;
  } catch (err) {
    console.error('[FCM] Failed to send push notification:', err);
    return false;
  }
};

/**
 * Send push notifications to multiple FCM tokens (batch).
 * Used for community alerts where we need to notify many nearby citizens at once.
 */
export const sendBatchPushNotifications = async (
  fcmTokens: string[],
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<{ success: number; failed: number }> => {
  if (fcmTokens.length === 0) return { success: 0, failed: 0 };

  const results = await Promise.allSettled(
    fcmTokens.map((token) => sendPushNotification(token, title, body, data))
  );

  const success = results.filter((r) => r.status === 'fulfilled' && r.value === true).length;
  const failed = fcmTokens.length - success;

  console.log(`[FCM] Batch sent: ${success} success, ${failed} failed out of ${fcmTokens.length}`);
  return { success, failed };
};
