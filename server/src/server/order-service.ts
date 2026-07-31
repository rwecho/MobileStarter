import { RuntimeConfig } from '@/domain/config';
import { ApiError } from './http';
import { findOrder, insertOrder, listOrders } from './order-repository';
import { paymentProvider } from './payment-providers';

type CreateOrderInput = Readonly<{
  appId: string;
  environment: string;
  userId: string;
  idempotencyKey: string;
  planId: string;
  config: RuntimeConfig;
}>;

export async function ordersForUser(userId: string) {
  return await listOrders(userId);
}

export async function createOrder(input: CreateOrderInput) {
  const existing = await findOrder(input.userId, input.idempotencyKey);
  if (existing) return existing;
  const plan = input.config.plans.find((item) => item.id === input.planId);
  if (!plan) throw new ApiError(404, 'PLAN_NOT_FOUND', '订阅方案不存在');
  const start = await paymentProvider(plan.provider).start({
    appId: input.appId,
    environment: input.environment,
    userId: input.userId,
    plan,
  });
  return await insertOrder({
    userId: input.userId,
    planId: plan.id,
    tierId: plan.tierId,
    idempotencyKey: input.idempotencyKey,
    amountMinor: plan.priceMinor,
    currency: plan.currency,
    provider: plan.provider,
    complete: start.complete,
  });
}
