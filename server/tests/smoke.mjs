// Live HTTP smoke trace for the account-security flow. Run against a freshly
// started server (e.g. `next start --port 3310`). Not part of `npm test`.
import { DatabaseSync } from 'node:sqlite';

const BASE = process.env.SMOKE_BASE ?? 'http://127.0.0.1:3310';
const H = { 'content-type': 'application/json', 'x-app-id': 'mobileui' };
const stamp = Date.now();
const email = `smoke-${stamp}@test.local`;
let pass = 0;
const fail = [];
function check(name, cond) {
  if (cond) { pass += 1; console.log(`  ✔ ${name}`); }
  else { fail.push(name); console.log(`  ✖ ${name}`); }
}
async function req(path, body) {
  const res = await fetch(`${BASE}${path}`, { method: 'POST', headers: H, body: JSON.stringify(body) });
  const json = await res.json().catch(() => ({}));
  return { status: res.status, json };
}

console.log('1. passwordPolicy published in bootstrap');
const boot = await (await fetch(`${BASE}/api/v1/bootstrap`, { headers: { 'x-app-id': 'mobileui' } })).json();
check('config.auth.passwordPolicy present', !!boot?.data?.config?.auth?.passwordPolicy?.minLength);

console.log('2. sign-up WITHOUT consent rejected (400 VALIDATION_ERROR)');
const noConsent = await req('/api/v1/auth/sign-up', { email, password: 'Test1234', username: 'smoke1' });
check('400 + consentVersion field error', noConsent.status === 400 && !!noConsent.json?.error?.fieldErrors?.consentVersion);

console.log('3. sign-up WITH consent succeeds (201, tokens, unverified)');
const signUp = await req('/api/v1/auth/sign-up', { email, password: 'Test1234', username: 'smoke1', consentVersion: '2026-07-29' });
check('201', signUp.status === 201);
check('returns accessToken', !!signUp.json?.data?.token);
check('returns refreshToken', !!signUp.json?.data?.refreshToken);
check('emailVerified false', signUp.json?.data?.user?.emailVerified === false);
check('consentVersion recorded', signUp.json?.data?.user?.consentVersion === '2026-07-29');
const refreshToken = signUp.json?.data?.refreshToken;

console.log('4. email verification via code read from DB');
const db = new DatabaseSync('data/smoke.db');
const row = db.prepare("SELECT payload FROM outbound_messages WHERE template='email_verification_code' AND recipient=? ORDER BY created_at DESC LIMIT 1").get(email);
const code = row ? JSON.parse(row.payload).code : null;
check('verification code delivered to outbound_messages', !!code);
const verify = await req('/api/v1/auth/verify-email', { email, code });
check('verified', verify.status === 200 && verify.json?.data?.verified === true);
const reuse = await req('/api/v1/auth/verify-email', { email, code });
check('reuse rejected (400)', reuse.status === 400);

console.log('5. sign-in returns tokens');
const signIn = await req('/api/v1/auth/sign-in', { identifier: email, password: 'Test1234', deviceName: 'smoke' });
check('200 + token', signIn.status === 200 && !!signIn.json?.data?.token);

console.log('6. refresh rotates; reuse revokes family');
const rotated = await req('/api/v1/auth/refresh', { refreshToken });
check('refresh 200 + new tokens', rotated.status === 200 && rotated.json?.data?.refreshToken && rotated.json?.data?.refreshToken !== refreshToken);
const reuseRefresh = await req('/api/v1/auth/refresh', { refreshToken });
check('reused refresh -> REFRESH_TOKEN_REUSED', reuseRefresh.status === 401 && reuseRefresh.json?.error?.code === 'REFRESH_TOKEN_REUSED');
const reuseRotated = await req('/api/v1/auth/refresh', { refreshToken: rotated.json.data.refreshToken });
check('rotated token also dead after family revoke', reuseRotated.status === 401);

console.log('7. sign-in lockout after repeated failures');
const lockEmail = `lock-${stamp}@test.local`;
await req('/api/v1/auth/sign-up', { email: lockEmail, password: 'Test1234', username: `lock-${stamp}`, consentVersion: '2026-07-29' });
for (let i = 0; i < 5; i += 1) await req('/api/v1/auth/sign-in', { identifier: lockEmail, password: 'Wrong-Pass-1', deviceName: 'smoke' });
const locked = await req('/api/v1/auth/sign-in', { identifier: lockEmail, password: 'Test1234', deviceName: 'smoke' });
check('locked -> SIGN_IN_LOCKED with retryAfterSeconds', locked.status === 429 && locked.json?.error?.code === 'SIGN_IN_LOCKED' && !!locked.json?.error?.retryAfterSeconds);

console.log(`\n${pass} passed, ${fail.length} failed`);
process.exit(fail.length ? 1 : 0);
