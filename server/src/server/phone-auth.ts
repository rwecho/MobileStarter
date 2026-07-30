import { database, nowIso, runTransaction } from './database';
import { createUserSession } from './auth';
import { ApiError } from './http';
import { createId, hashToken } from './ids';

const challengeMinutes = 10;
const resendCooldownMs = 60_000;
const maximumAttempts = 5;

export async function requestPhoneCode(appId: string, phone: string) {
  const latest = database.prepare(`
    SELECT created_at FROM phone_auth_challenges
    WHERE app_id = ? AND phone = ? ORDER BY created_at DESC LIMIT 1
  `).get(appId, phone) as { created_at: string } | undefined;
  if (latest && Date.now() - Date.parse(latest.created_at) < resendCooldownMs) {
    return requestResult();
  }
  const code = String(crypto.getRandomValues(new Uint32Array(1))[0] % 1_000_000)
    .padStart(6, '0');
  database.prepare(`
    INSERT INTO phone_auth_challenges(
      id, app_id, phone, code_hash, expires_at, created_at
    ) VALUES (?, ?, ?, ?, ?, ?)
  `).run(
    createId(),
    appId,
    phone,
    codeHash(appId, phone, code),
    new Date(Date.now() + challengeMinutes * 60_000).toISOString(),
    nowIso(),
  );
  await deliverPhoneCode(appId, phone, code);
  return requestResult();
}

export function verifyPhoneCode(
  appId: string,
  phone: string,
  code: string,
  deviceName: string,
) {
  const challenge = database.prepare(`
    SELECT * FROM phone_auth_challenges
    WHERE app_id = ? AND phone = ? AND used_at IS NULL
    ORDER BY created_at DESC LIMIT 1
  `).get(appId, phone) as ChallengeRow | undefined;
  if (!challenge || challenge.expires_at <= nowIso()) {
    throw new ApiError(400, 'PHONE_CODE_EXPIRED', '验证码无效或已过期');
  }
  if (challenge.attempts >= maximumAttempts) {
    throw new ApiError(429, 'PHONE_CODE_LOCKED', '尝试次数过多，请重新获取验证码');
  }
  if (challenge.code_hash !== codeHash(appId, phone, code)) {
    database.prepare(
      'UPDATE phone_auth_challenges SET attempts = attempts + 1 WHERE id = ?',
    ).run(challenge.id);
    throw new ApiError(400, 'PHONE_CODE_INVALID', '验证码无效或已过期');
  }
  const userId = findOrCreatePhoneUser(appId, phone);
  runTransaction(() => {
    database.prepare(
      'UPDATE phone_auth_challenges SET used_at = ? WHERE id = ?',
    ).run(nowIso(), challenge.id);
  });
  return createUserSession(userId, appId, deviceName);
}

function findOrCreatePhoneUser(appId: string, phone: string) {
  const subject = `${appId}:${phone}`;
  const identity = database.prepare(`
    SELECT user_id FROM external_identities
    WHERE provider = 'phone' AND provider_subject = ?
  `).get(subject) as { user_id: string } | undefined;
  if (identity) return identity.user_id;
  const userId = createId();
  const createdAt = nowIso();
  const email = `phone-${hashToken(subject).slice(0, 24)}@phone.invalid`;
  database.prepare(`
    INSERT INTO users(
      id, app_id, email, password_hash, username, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?)
  `).run(
    userId,
    appId,
    email,
    `external$${createId()}`,
    `手机用户 ${phone.slice(-4)}`,
    createdAt,
    createdAt,
  );
  database.prepare(`
    INSERT INTO external_identities(
      id, user_id, provider, provider_subject, created_at
    ) VALUES (?, ?, 'phone', ?, ?)
  `).run(createId(), userId, subject, createdAt);
  return userId;
}

async function deliverPhoneCode(appId: string, phone: string, code: string) {
  const messageId = createId();
  const payload = JSON.stringify({ code, expiresInMinutes: challengeMinutes });
  database.prepare(`
    INSERT INTO outbound_messages(
      id, app_id, channel, recipient, template, payload, status, created_at
    ) VALUES (?, ?, 'sms', ?, 'phone_login_code', ?, 'pending', ?)
  `).run(messageId, appId, phone, payload, nowIso());
  const endpoint = process.env.MOBILEUI_SMS_ENDPOINT;
  if (!endpoint) return;
  try {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${process.env.MOBILEUI_SMS_API_KEY ?? ''}`,
      },
      body: JSON.stringify({ appId, to: phone, template: 'phone_login_code', code }),
      signal: AbortSignal.timeout(8000),
    });
    if (!response.ok) throw new Error(`HTTP_${response.status}`);
    database.prepare(
      'UPDATE outbound_messages SET status = ?, sent_at = ? WHERE id = ?',
    ).run('sent', nowIso(), messageId);
  } catch {
    database.prepare(`
      UPDATE outbound_messages SET status = ?, error_code = ? WHERE id = ?
    `).run('failed', 'DELIVERY_FAILED', messageId);
  }
}

function requestResult() {
  return { accepted: true, resendAfterSeconds: 60 };
}

function codeHash(appId: string, phone: string, code: string) {
  const pepper = process.env.MOBILEUI_PHONE_PEPPER ?? 'local-development-phone-pepper';
  return hashToken(`${pepper}:${appId}:${phone}:${code}`);
}

type ChallengeRow = {
  id: string;
  code_hash: string;
  attempts: number;
  expires_at: string;
};
