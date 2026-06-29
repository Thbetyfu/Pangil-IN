import { Request } from 'express';

export enum Role {
  CITIZEN = 'CITIZEN',
  POLICE_OPERATOR = 'POLICE_OPERATOR',
  SUPERADMIN = 'SUPERADMIN',
}

export enum ReportType {
  SOS_VOICE = 'SOS_VOICE',
  VISUAL_REPORT = 'VISUAL_REPORT',
}

export enum ReportStatus {
  PENDING = 'PENDING',
  VALIDATED = 'VALIDATED',
  ON_PROCESS = 'ON_PROCESS',
  RESOLVED = 'RESOLVED',
  REJECTED = 'REJECTED',
}

export enum UrgencyLevel {
  LOW = 'LOW',
  MEDIUM = 'MEDIUM',
  HIGH = 'HIGH',
  CRITICAL = 'CRITICAL',
}

export enum FPSMode {
  LOW = 'LOW',
  HIGH = 'HIGH',
}

export enum CCTVStatus {
  ACTIVE = 'ACTIVE',
  INACTIVE = 'INACTIVE',
  MAINTENANCE = 'MAINTENANCE',
}

export enum AlertStatus {
  UNVERIFIED = 'UNVERIFIED',
  VALIDATED_CRIME = 'VALIDATED_CRIME',
  FALSE_ALARM = 'FALSE_ALARM',
}

export enum PatrolStatus {
  AVAILABLE = 'AVAILABLE',
  ON_DUTY = 'ON_DUTY',
  OFFLINE = 'OFFLINE',
}

export interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
    email: string;
    role: Role;
  };
}
