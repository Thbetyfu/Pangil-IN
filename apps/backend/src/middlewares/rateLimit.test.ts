import test from 'node:test';
import assert from 'node:assert';
import express from 'express';
import { apiTokenLimiter, sosLimiter } from './rateLimit';

test('apiTokenLimiter blocks the 6th login request within window', async () => {
  const app = express();
  
  // Use a unique header or path to avoid interference
  app.get('/test-login', apiTokenLimiter, (req, res) => {
    res.status(200).json({ status: 'success' });
  });

  const server = app.listen(0);
  const address = server.address() as any;
  const port = address.port;

  try {
    // Perform 5 successful requests
    for (let i = 0; i < 5; i++) {
      const res = await fetch(`http://localhost:${port}/test-login`);
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.headers.get('X-RateLimit-Limit'), '5');
      assert.strictEqual(res.headers.get('X-RateLimit-Remaining'), (4 - i).toString());
    }

    // The 6th request should fail with 429 Too Many Requests
    const blockRes = await fetch(`http://localhost:${port}/test-login`);
    assert.strictEqual(blockRes.status, 429);
    const data = (await blockRes.json()) as any;
    assert.strictEqual(data.status, 'error');
    assert.strictEqual(data.message, 'Too many login requests from this IP. Please try again after a minute.');
  } finally {
    server.close();
  }
});

test('sosLimiter blocks the 4th SOS trigger request within window per user', async () => {
  const app = express();

  // Middleware mock user authentication
  let currentUserId = 'user-1';
  app.use((req: any, res, next) => {
    req.user = { id: currentUserId };
    next();
  });

  app.get('/test-sos', sosLimiter, (req, res) => {
    res.status(200).json({ status: 'success' });
  });

  const server = app.listen(0);
  const address = server.address() as any;
  const port = address.port;

  try {
    // Perform 3 successful requests for user-1
    for (let i = 0; i < 3; i++) {
      const res = await fetch(`http://localhost:${port}/test-sos`);
      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.headers.get('X-RateLimit-Limit'), '3');
      assert.strictEqual(res.headers.get('X-RateLimit-Remaining'), (2 - i).toString());
    }

    // The 4th request should fail with 429
    const blockRes = await fetch(`http://localhost:${port}/test-sos`);
    assert.strictEqual(blockRes.status, 429);

    // If we switch to user-2, they should have their own fresh limit (QoS separation)
    currentUserId = 'user-2';
    const user2Res = await fetch(`http://localhost:${port}/test-sos`);
    assert.strictEqual(user2Res.status, 200);
    assert.strictEqual(user2Res.headers.get('X-RateLimit-Remaining'), '2');
  } finally {
    server.close();
  }
});
