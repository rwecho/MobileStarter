import { database, nowIso, runTransaction } from './database';
import { createId } from './ids';

export type OrderView = Readonly<{
  id: string;
  planId: string;
  status: string;
  amountMinor: number;
  currency: string;
  provider: string;
  createdAt: string;
  completedAt: string | null;
}>;

type NewOrder = Readonly<{
  userId: string;
  planId: string;
  tierId: string;
  idempotencyKey: string;
  amountMinor: number;
  currency: string;
  provider: string;
  complete: boolean;
}>;

const selectColumns = `
  id, plan_id AS planId, status, amount_minor AS amountMinor,
  currency, provider, created_at AS createdAt, completed_at AS completedAt
`;

export function listOrders(userId: string) {
  return database.prepare(`
    SELECT ${selectColumns} FROM orders
    WHERE user_id = ? ORDER BY created_at DESC
  `).all(userId) as unknown as readonly OrderView[];
}

export function findOrder(userId: string, idempotencyKey: string) {
  return database.prepare(`
    SELECT ${selectColumns} FROM orders
    WHERE user_id = ? AND idempotency_key = ?
  `).get(userId, idempotencyKey) as OrderView | undefined;
}

export function insertOrder(input: NewOrder) {
  const orderId = createId();
  const timestamp = nowIso();
  const status = input.complete ? 'success' : 'pending';
  const completedAt = input.complete ? timestamp : null;
  runTransaction(() => {
    database.prepare(`
      INSERT INTO orders(
        id, user_id, plan_id, idempotency_key, status, amount_minor,
        currency, provider, created_at, completed_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      orderId, input.userId, input.planId, input.idempotencyKey, status,
      input.amountMinor, input.currency, input.provider, timestamp, completedAt,
    );
    if (input.complete) {
      database.prepare(
        'UPDATE users SET tier_id = ?, updated_at = ? WHERE id = ?',
      ).run(input.tierId, timestamp, input.userId);
    }
  });
  return findOrder(input.userId, input.idempotencyKey);
}
