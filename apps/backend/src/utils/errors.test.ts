import test from 'node:test';
import assert from 'node:assert';
import { Request, Response, NextFunction } from 'express';
import {
  AppError,
  BadRequestError,
  UnauthorizedError,
  ForbiddenError,
  NotFoundError,
  errorHandler
} from './errors';

test('AppError sets message, statusCode, and isOperational correctly', () => {
  const error = new AppError('Custom error', 418);
  assert.strictEqual(error.message, 'Custom error');
  assert.strictEqual(error.statusCode, 418);
  assert.strictEqual(error.isOperational, true);
});

test('AppError subclasses set correct status codes and default messages', () => {
  const badRequest = new BadRequestError();
  assert.strictEqual(badRequest.statusCode, 400);
  assert.strictEqual(badRequest.message, 'Bad Request');

  const unauthorized = new UnauthorizedError('Custom unauthorized');
  assert.strictEqual(unauthorized.statusCode, 401);
  assert.strictEqual(unauthorized.message, 'Custom unauthorized');

  const forbidden = new ForbiddenError();
  assert.strictEqual(forbidden.statusCode, 403);
  assert.strictEqual(forbidden.message, 'Forbidden');

  const notFound = new NotFoundError();
  assert.strictEqual(notFound.statusCode, 404);
  assert.strictEqual(notFound.message, 'Not Found');
});

test('errorHandler responds with correct JSON and status code for AppError', () => {
  let responseStatus = 0;
  let responseJson: any = null;

  const mockReq = {} as Request;
  const mockRes = {
    status(code: number) {
      responseStatus = code;
      return this;
    },
    json(data: any) {
      responseJson = data;
      return this;
    }
  } as unknown as Response;
  const mockNext = (() => {}) as NextFunction;

  const error = new BadRequestError('Invalid input field');
  errorHandler(error, mockReq, mockRes, mockNext);

  assert.strictEqual(responseStatus, 400);
  assert.deepStrictEqual(responseJson, {
    status: 'error',
    message: 'Invalid input field'
  });
});

test('errorHandler responds with 500 status code for generic error', () => {
  let responseStatus = 0;
  let responseJson: any = null;

  const mockReq = {} as Request;
  const mockRes = {
    status(code: number) {
      responseStatus = code;
      return this;
    },
    json(data: any) {
      responseJson = data;
      return this;
    }
  } as unknown as Response;
  const mockNext = (() => {}) as NextFunction;

  const error = new Error('Database crash');
  
  // Suppress console.error output during test
  const originalError = console.error;
  console.error = () => {};
  
  errorHandler(error, mockReq, mockRes, mockNext);
  
  console.error = originalError;

  assert.strictEqual(responseStatus, 500);
  assert.deepStrictEqual(responseJson, {
    status: 'error',
    message: 'Internal Server Error'
  });
});
