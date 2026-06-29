import { Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { Role, AuthenticatedRequest } from '../types/enums';
import { UnauthorizedError, ForbiddenError } from '../utils/errors';

const JWT_SECRET = process.env.JWT_SECRET || 'panggil_in_super_secret_key_change_me_in_production';

interface DecodedToken {
  id: string;
  email: string;
  role: Role;
}

export const authenticate = (req: AuthenticatedRequest, res: Response, next: NextFunction): void => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw new UnauthorizedError('Access token is missing or invalid');
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, JWT_SECRET) as DecodedToken;
    req.user = decoded;
    next();
  } catch (error) {
    throw new UnauthorizedError('Invalid or expired token');
  }
};

export const requireRole = (roles: Role[]) => {
  return (req: AuthenticatedRequest, res: Response, next: NextFunction): void => {
    if (!req.user) {
      throw new UnauthorizedError('Not authenticated');
    }

    if (!roles.includes(req.user.role)) {
      throw new ForbiddenError('You do not have permission to access this resource');
    }

    next();
  };
};
