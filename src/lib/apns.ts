import { readFileSync } from 'fs';
import { sign } from 'jsonwebtoken';
import http2 from 'http2';
import { config } from './config';
import { getDeviceTokens } from './db';
import { logger } from './logger';

const APNS_HOST_PROD = 'https://api.push.apple.com';
const APNS_HOST_DEV = 'https://api.sandbox.push.apple.com';

interface APNsPayload {
  aps: {
    alert: {
      title: string;
      body: string;
      subtitle?: string;
    };
    sound?: string;
    badge?: number;
    'thread-id'?: string;
    'interruption-level'?: 'passive' | 'active' | 'time-sensitive' | 'critical';
    category?: string;
  };
  // Custom data
  [key: string]: unknown;
}

let cachedJWT: { token: string; expiresAt: number } | null = null;

function getAPNsJWT(): string {
  // Cache JWT for 50 minutes (APNs JWTs are valid for 60 min)
  const now = Math.floor(Date.now() / 1000);
  if (cachedJWT && cachedJWT.expiresAt > now) {
    return cachedJWT.token;
  }

  if (!config.apnsKeyPath || !config.apnsKeyId || !config.apnsTeamId) {
    throw new Error('APNs not configured: missing key path, key ID, or team ID');
  }

  const key = readFileSync(config.apnsKeyPath, 'utf8');
  const token = sign({}, key, {
    algorithm: 'ES256',
    keyid: config.apnsKeyId,
    issuer: config.apnsTeamId,
    expiresIn: '1h',
    header: {
      alg: 'ES256',
      kid: config.apnsKeyId,
    },
  });

  cachedJWT = { token, expiresAt: now + 3000 }; // Cache for 50 min
  return token;
}

function isAPNsConfigured(): boolean {
  return !!(config.apnsKeyPath && config.apnsKeyId && config.apnsTeamId);
}

async function sendPushNotification(
  deviceToken: string,
  payload: APNsPayload,
  options: { expiration?: number; priority?: number; collapseId?: string } = {}
): Promise<boolean> {
  const host = config.apnsProduction ? APNS_HOST_PROD : APNS_HOST_DEV;

  return new Promise((resolve) => {
    const client = http2.connect(host);

    client.on('error', (err) => {
      logger.error({ err, deviceToken }, 'APNs connection error');
      client.close();
      resolve(false);
    });

    const jwt = getAPNsJWT();
    const body = JSON.stringify(payload);

    const headers: http2.OutgoingHttpHeaders = {
      ':method': 'POST',
      ':path': `/3/device/${deviceToken}`,
      'authorization': `bearer ${jwt}`,
      'apns-topic': config.apnsBundleId,
      'apns-push-type': 'alert',
      'apns-priority': String(options.priority ?? 10),
    };

    if (options.expiration) {
      headers['apns-expiration'] = String(options.expiration);
    }
    if (options.collapseId) {
      headers['apns-collapse-id'] = options.collapseId;
    }

    const req = client.request(headers);

    req.on('response', (responseHeaders) => {
      const status = responseHeaders[':status'];
      if (status === 200) {
        logger.info({ deviceToken: deviceToken.substring(0, 8) + '...' }, 'APNs push sent');
        resolve(true);
      } else {
        let responseBody = '';
        req.on('data', (chunk: Buffer) => { responseBody += chunk.toString(); });
        req.on('end', () => {
          logger.error({ status, body: responseBody, deviceToken: deviceToken.substring(0, 8) + '...' }, 'APNs push failed');
          resolve(false);
        });
      }
    });

    req.on('error', (err) => {
      logger.error({ err }, 'APNs request error');
      resolve(false);
    });

    req.write(body);
    req.end();

    // Close connection after response
    req.on('close', () => client.close());
  });
}

/**
 * Send a notification to all registered iOS devices.
 */
export async function notifyAllDevices(
  title: string,
  body: string,
  options: {
    subtitle?: string;
    threadId?: string;
    category?: string;
    collapseId?: string;
    customData?: Record<string, unknown>;
    interruptionLevel?: 'passive' | 'active' | 'time-sensitive';
  } = {}
): Promise<number> {
  if (!isAPNsConfigured()) {
    logger.debug('APNs not configured, skipping push notification');
    return 0;
  }

  const tokens = getDeviceTokens('ios');
  if (tokens.length === 0) {
    logger.debug('No iOS devices registered, skipping push');
    return 0;
  }

  const payload: APNsPayload = {
    aps: {
      alert: {
        title,
        body,
        subtitle: options.subtitle,
      },
      sound: 'default',
      'thread-id': options.threadId,
      'interruption-level': options.interruptionLevel ?? 'active',
      category: options.category,
    },
    ...options.customData,
  };

  let successCount = 0;
  for (const token of tokens) {
    const success = await sendPushNotification(token, payload, {
      collapseId: options.collapseId,
    });
    if (success) successCount++;
  }

  logger.info({ sent: successCount, total: tokens.length, title }, 'Push notifications sent');
  return successCount;
}

/**
 * Send briefing ready notification.
 */
export async function notifyBriefingReady(): Promise<void> {
  await notifyAllDevices(
    'Morning Briefing Ready',
    'Your daily briefing is prepared with thread updates and connections.',
    {
      category: 'BRIEFING',
      collapseId: 'daily-briefing',
      threadId: 'briefing',
      customData: { type: 'briefing' },
    }
  );
}

/**
 * Send new thread detected notification.
 */
export async function notifyNewThread(threadName: string): Promise<void> {
  await notifyAllDevices(
    'New Thread Detected',
    `"${threadName}" has emerged from your notes.`,
    {
      category: 'THREAD',
      threadId: 'threads',
      customData: { type: 'thread', threadName },
    }
  );
}

