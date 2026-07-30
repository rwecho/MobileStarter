import { NextRequest } from 'next/server';
import { z } from 'zod';
import { getClientContext } from '@/server/client-context';
import { rollbackConfig } from '@/server/config-control';
import { handleError, ok } from '@/server/http';
import { authorizeAdmin } from '../route';

const inputSchema = z.object({ version: z.number().int().positive() });

export async function POST(request: NextRequest) {
  try {
    authorizeAdmin(request);
    const input = inputSchema.parse(await request.json());
    const config = rollbackConfig(
      getClientContext(request),
      input.version,
      request.headers.get('x-admin-actor') ?? 'admin',
    );
    return ok(config);
  } catch (error) {
    return handleError(error);
  }
}
