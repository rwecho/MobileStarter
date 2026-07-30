import { database } from '@/server/database';
import { handleError, ok } from '@/server/http';

export function GET() {
  try {
    database.prepare('SELECT 1').get();
    return ok({ status: 'ready', database: 'connected' });
  } catch (error) {
    return handleError(error);
  }
}

