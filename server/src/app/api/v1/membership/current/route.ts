import { NextRequest } from 'next/server';
import { requireAuth } from '@/server/auth';
import { getClientContext } from '@/server/client-context';
import { getRuntimeConfig, database } from '@/server/database';
import { handleError, ok } from '@/server/http';
import {
  listActiveEntitlements, resolveTierIdFromEntitlementKeys,
} from '@/server/entitlement-service';

export async function GET(request: NextRequest) {
  try {
    const { user } = await requireAuth(request);
    // tier 读时从生效权益重推导：权益表是唯一事实源（退款/到期即时降级，
    // users.tier_id 只是展示/运维参考）。
    const client = getClientContext(request);
    const config = await getRuntimeConfig(user.app_id, client.environment);
    const entitlements = await listActiveEntitlements(user.id, user.app_id);
    const tier = resolveTierIdFromEntitlementKeys(
      config, entitlements.map((e) => e.entitlement_key),
    );
    const sub = await database.prepare(
      `SELECT plan_id AS planId, status, renew_at AS renewAt FROM subscriptions
       WHERE user_id = ? AND app_id = ? ORDER BY updated_at DESC LIMIT 1`,
    ).get(user.id, user.app_id) as { planId: string; status: string; renewAt: string | null } | undefined;
    return ok({
      tier,
      entitlements: entitlements.map((e) => ({ key: e.entitlement_key, expiresAt: e.expires_at })),
      subscription: sub ?? null,
    });
  } catch (error) {
    return handleError(error);
  }
}
