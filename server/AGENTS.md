# Next.js control-plane rules

These rules extend the repository root rules for `server/`.

## Architecture

- Route handlers validate transport input and call an application service.
- Domain services own authorization, state transitions, and transactions.
- Repositories own SQL. UI and route handlers never contain SQL.
- External payments, object storage, email, and push use typed provider ports.
- Every mutation returning success must be durably committed first.

## Security and data

- Passwords use Node scrypt with per-password random salts. Session tokens are
  random and stored only as hashes.
- Protected queries are scoped by both authenticated user and `appId`.
- Destructive account operations require recent password reauthentication.
- Webhooks require provider verification and persistent event idempotency.
- Logs never include passwords, session tokens, reset tokens, or provider secrets.
- Amounts use integer minor units and ISO 4217 currency codes.
- Times are stored as UTC ISO strings.

## API

- Public API lives under `/api/v1`.
- Parse all external input with Zod.
- Errors use `code`, `message`, `fieldErrors`, `traceId`, and `retryable`.
- Mutating order/payment endpoints require an idempotency key.
- Route files target 100 lines and may not exceed the repository hard limit.

## Verification

- `npm run typecheck`, `npm run lint`, and `npm test` must pass.
- Database initialization and seed operations must be idempotent.
- Critical auth, configuration, membership, order, and notification transitions
  require integration tests.
