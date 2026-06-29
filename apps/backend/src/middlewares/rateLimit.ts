import { Request, Response, NextFunction } from 'express';

interface RateLimitConfig {
  windowMs: number;
  max: number;
  message: string;
}

interface ClientRecord {
  requests: number;
  resetTime: number;
}

const stores = new Map<string, Map<string, ClientRecord>>();

export const createRateLimiter = (name: string, config: RateLimitConfig) => {
  if (!stores.has(name)) {
    stores.set(name, new Map<string, ClientRecord>());
  }
  const store = stores.get(name)!;

  // Cleanup expired entries periodically
  const timer = setInterval(() => {
    const now = Date.now();
    for (const [key, record] of store.entries()) {
      if (now > record.resetTime) {
        store.delete(key);
      }
    }
  }, 30000);
  
  if (timer.unref) {
    timer.unref();
  }

  return (req: Request, res: Response, next: NextFunction): void => {
    // Determine the rate limiting key: User ID if authenticated SOS, otherwise IP Address
    let key: string = req.ip || 'unknown-ip';
    const authReq = req as any;
    if (name === 'sos' && authReq.user && authReq.user.id) {
      key = authReq.user.id;
    }

    const now = Date.now();
    let record = store.get(key);

    if (!record || now > record.resetTime) {
      record = {
        requests: 0,
        resetTime: now + config.windowMs,
      };
    }

    record.requests++;
    store.set(key, record);

    const remaining = Math.max(0, config.max - record.requests);
    res.setHeader('X-RateLimit-Limit', config.max);
    res.setHeader('X-RateLimit-Remaining', remaining);
    res.setHeader('X-RateLimit-Reset', Math.ceil(record.resetTime / 1000));

    if (record.requests > config.max) {
      res.status(429).json({
        status: 'error',
        message: config.message,
      });
      return;
    }

    next();
  };
};

export const apiTokenLimiter = createRateLimiter('api-token', {
  windowMs: 60000, // 1 minute
  max: 5,
  message: 'Too many login requests from this IP. Please try again after a minute.',
});

export const sosLimiter = createRateLimiter('sos', {
  windowMs: 60000, // 1 minute
  max: 3,
  message: 'Too many SOS requests. Please wait a minute before triggering again.',
});
