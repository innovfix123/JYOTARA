import { PostgresDatabase } from './postgres';
import type { D1Database } from '@cloudflare/workers-types';

if (!process.env.DATABASE_URL) throw new Error('DATABASE_URL is required');
export const database = new PostgresDatabase(process.env.DATABASE_URL);
// The existing handlers use prepare/bind/run/first/all and atomic batch only.
// The compatibility surface is verified against PostgreSQL integration tests.
export const env: Cloudflare.Env = {
  ...process.env,
  PROKERALA_ENVIRONMENT: process.env.PROKERALA_ENVIRONMENT === 'production' ? 'production' : 'test',
  DB: database as unknown as D1Database,
};
