import { NextRequest } from 'next/server';
import { requireAuth } from '@/server/auth';
import { getClientContext } from '@/server/client-context';
import { getRuntimeConfig } from '@/server/database';
import { handleError, ok } from '@/server/http';
import {
  ENTITLEMENT_TTL_SECONDS, signEntitlementToken,
} from '@/server/entitlement-token';
import {
  listActiveEntitlements, resolveTierIdFromEntitlementKeys,
} from '@/server/entitlement-service';

/**
 * POST /api/v1/me/entitlement
 *
 * Returns a short-lived HMAC-signed entitlement token for the calling user.
 * App-specific backends verify it (with the shared ENTITLEMENT_SIGNING_SECRET)
 * to grant Pro-tier quota. Free users receive `{ token: null }`.
 *
 * Tier is derived at read time from the active entitlement keys (the
 * entitlements table is the single source of truth): a refunded/expired user
 * stops minting tokens immediately, without any tier_id cleanup job.
 * users.tier_id is display/ops metadata only.
 */
export async function POST(request: NextRequest) {
  try {
    const { user } = await requireAuth(request);
    const client = getClientContext(request);
    const config = await getRuntimeConfig(user.app_id, client.environment);
    const entitlements = await listActiveEntitlements(user.id, user.app_id);
    const tierId = resolveTierIdFromEntitlementKeys(
      config, entitlements.map((e) => e.entitlement_key),
    );
    if (tierId === null) {
      return ok({ token: null as string | null, expiresAt: null as number | null });
    }
    const exp = Math.floor(Date.now() / 1000) + ENTITLEMENT_TTL_SECONDS;
    const token = signEntitlementToken({ exp, appId: user.app_id, tier: tierId });
    return ok({ token, expiresAt: exp });
  } catch (error) {
    return handleError(error);
  }
}
