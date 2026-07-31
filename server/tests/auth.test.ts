import assert from 'node:assert/strict';
import test, { after } from 'node:test';
const { signUp, signIn, revokeAllSessions } = await import('../src/server/auth.ts');
const { rotateRefreshToken } = await import('../src/server/refresh.ts');
const { verifyEmail, requestEmailVerificationResend } = await import('../src/server/email-verification.ts');
const {
  requestPasswordReset,
  resetPassword,
  verifyPasswordResetCode,
} = await import('../src/server/password-reset.ts');
const { validatePasswordAgainstPolicy } = await import('../src/server/passwords.ts');
const { signUpSchema } = await import('../src/server/schemas.ts');
const { hashToken } = await import('../src/server/ids.ts');
const { database, getRuntimeConfig, saveRuntimeConfig } = await import('../src/server/database.ts');
const { defaultConfig } = await import('../src/domain/config.ts');
after(async () => database.close());

const APP = 'zhongbei';
const prefix = `auth-${process.pid}`;
const policy = defaultConfig.auth.passwordPolicy;
let counter = 0;
const nextEmail = () => `${prefix}-${counter++}@test.local`;

async function latestVerificationCode(email: string): Promise<string | undefined> {
  const row = await database.prepare(
    "SELECT payload FROM outbound_messages WHERE template = 'email_verification_code' AND recipient = ? ORDER BY created_at DESC LIMIT 1",
  ).get(email) as { payload: string } | undefined;
  return row ? (JSON.parse(row.payload).code as string) : undefined;
}

async function latestResetCode(email: string): Promise<string | undefined> {
  const row = await database.prepare(
    "SELECT payload FROM outbound_messages WHERE template = 'password_reset_code' AND recipient = ? ORDER BY created_at DESC LIMIT 1",
  ).get(email) as { payload: string } | undefined;
  return row ? (JSON.parse(row.payload).code as string) : undefined;
}

async function userRow(email: string) {
  return await database.prepare(
    'SELECT email_verified, consent_version FROM users WHERE app_id = ? AND email = ?',
  ).get(APP, email) as { email_verified: number; consent_version: string | null };
}

test('sign-up schema requires consent version and a minimum password length', () => {
  assert.equal(signUpSchema.safeParse({
    email: nextEmail(), password: 'Test1234', username: 'noconsent',
  }).success, false);
  assert.equal(signUpSchema.safeParse({
    email: nextEmail(), password: 'short', username: 'weakpw', consentVersion: '2026-07-29',
  }).success, false);
});

test('development test account signs in with email, username, or phone', async () => {
  for (const identifier of ['test@zhongbei.local', 'test', '+8613800000000']) {
    const result = await signIn({
      appId: APP,
      identifier,
      password: 'test123',
      deviceName: 'test-runner',
    });
    assert.equal(result.user.email, 'test@zhongbei.local');
  }
});

test('sign-up enforces the runtime password policy', async () => {
  await assert.rejects(
    signUp({
      appId: APP, email: nextEmail(), password: 'NoDigitHere', username: `u-${counter}`,
      consentVersion: '2026-07-29', deviceName: 'test-runner',
    }),
    (error: { code: string }) => error.code === 'VALIDATION_ERROR',
  );
});

test('sign-up persists consent, leaves email unverified, and issues a verification code', async () => {
  const email = nextEmail();
  const result = await signUp({
    appId: APP, email, password: 'Test1234', username: `u-${counter}`,
    consentVersion: '2026-07-29', deviceName: 'test-runner',
  });
  assert.ok(result.token);
  assert.ok(result.refreshToken);
  assert.equal(result.user.emailVerified, false);
  assert.equal(result.user.consentVersion, '2026-07-29');
  assert.equal((await userRow(email)).consent_version, '2026-07-29');
  assert.equal((await userRow(email)).email_verified, 0);
  assert.ok(await latestVerificationCode(email));
});

test('same-version legacy config is upgraded with a password policy', async () => {
  const legacy = {
    ...defaultConfig,
    auth: { providers: defaultConfig.auth.providers },
  };
  await database.prepare(`
    UPDATE runtime_configs SET document = ?
    WHERE app_id = ? AND environment = 'development'
  `).run(JSON.stringify(legacy), APP);
  const upgraded = await getRuntimeConfig(APP);
  assert.deepEqual(upgraded.auth.passwordPolicy, defaultConfig.auth.passwordPolicy);
  await saveRuntimeConfig(defaultConfig, APP);
});

test('repeated failed sign-ins lock the account and clear after cooldown', async () => {
  const email = nextEmail();
  const password = 'Test1234';
  await signUp({
    appId: APP, email, password, username: `u-${counter}`,
    consentVersion: '2026-07-29', deviceName: 'test-runner',
  });
  for (let i = 0; i < 5; i += 1) {
    await assert.rejects(
      signIn({ appId: APP, identifier: email, password: 'Wrong-Pass-1', deviceName: 'test-runner' }),
      (error: { code: string }) => error.code === 'INVALID_CREDENTIALS',
    );
  }
  await assert.rejects(
    signIn({ appId: APP, identifier: email, password, deviceName: 'test-runner' }),
    (error: { code: string }) => error.code === 'SIGN_IN_LOCKED',
  );
  await database.prepare('UPDATE sign_in_attempts SET locked_until = ? WHERE app_id = ? AND identifier = ?')
    .run(new Date(Date.now() - 1000).toISOString(), APP, email);
  const recovered = await signIn({ appId: APP, identifier: email, password, deviceName: 'test-runner' });
  assert.ok(recovered.token);
});

test('refresh token rotates and the previous token is revoked', async () => {
  const email = nextEmail();
  const { refreshToken: first } = await signUp({
    appId: APP, email, password: 'Test1234', username: `u-${counter}`,
    consentVersion: '2026-07-29', deviceName: 'test-runner',
  });
  const rotated = await rotateRefreshToken(APP, first);
  assert.ok(rotated.token);
  assert.notEqual(rotated.refreshToken, first);
  const stale = await database.prepare(
    'SELECT revoked_at FROM refresh_tokens WHERE token_hash = ?',
  ).get(hashToken(first)) as { revoked_at: string | null };
  assert.ok(stale.revoked_at);
});

test('reusing a rotated refresh token revokes the whole family', async () => {
  const email = nextEmail();
  const { refreshToken: first } = await signUp({
    appId: APP, email, password: 'Test1234', username: `u-${counter}`,
    consentVersion: '2026-07-29', deviceName: 'test-runner',
  });
  const { refreshToken: second } = await rotateRefreshToken(APP, first);
  await assert.rejects(
    rotateRefreshToken(APP, first),
    (error: { code: string }) => error.code === 'REFRESH_TOKEN_REUSED',
  );
  await assert.rejects(
    rotateRefreshToken(APP, second),
    (error: { code: string }) => error.code === 'REFRESH_TOKEN_REUSED',
  );
});

test('sign-out-all invalidates refresh tokens', async () => {
  const email = nextEmail();
  const { refreshToken, user } = await signUp({
    appId: APP, email, password: 'Test1234', username: `u-${counter}`,
    consentVersion: '2026-07-29', deviceName: 'test-runner',
  });
  await revokeAllSessions(user.id);
  await assert.rejects(
    rotateRefreshToken(APP, refreshToken),
    (error: { code: string }) => error.code === 'REFRESH_TOKEN_REUSED',
  );
});

test('email verification rejects a wrong code, accepts the right one, and rejects reuse', async () => {
  const email = nextEmail();
  await signUp({
    appId: APP, email, password: 'Test1234', username: `u-${counter}`,
    consentVersion: '2026-07-29', deviceName: 'test-runner',
  });
  const code = (await latestVerificationCode(email))!;
  await assert.rejects(
    verifyEmail(APP, email, '000000'),
    (error: { code: string }) => error.code === 'EMAIL_CODE_INVALID',
  );
  assert.deepEqual(await verifyEmail(APP, email, code), { verified: true });
  assert.equal((await userRow(email)).email_verified, 1);
  await assert.rejects(
    verifyEmail(APP, email, code),
    (error: { code: string }) => error.code === 'EMAIL_CODE_EXPIRED',
  );
});

test('resend verification respects the cooldown window', async () => {
  const email = nextEmail();
  await signUp({
    appId: APP, email, password: 'Test1234', username: `u-${counter}`,
    consentVersion: '2026-07-29', deviceName: 'test-runner',
  });
  const before = await database.prepare(
    'SELECT COUNT(*) AS count FROM email_verifications WHERE app_id = ? AND email = ?',
  ).get(APP, email) as { count: number };
  await requestEmailVerificationResend(APP, email);
  const after = await database.prepare(
    'SELECT COUNT(*) AS count FROM email_verifications WHERE app_id = ? AND email = ?',
  ).get(APP, email) as { count: number };
  assert.equal(after.count, before.count);
});

test('password policy validation flags each missing requirement', () => {
  assert.ok(validatePasswordAgainstPolicy(policy, 'short').includes('PASSWORD_TOO_SHORT'));
  assert.ok(validatePasswordAgainstPolicy(policy, 'NoDigitsHere').includes('PASSWORD_MISSING_DIGIT'));
  assert.deepEqual(validatePasswordAgainstPolicy(policy, 'Test1234'), []);
});

test('password reset rejects weak passwords and accepts a policy-compliant password', async () => {
  const email = nextEmail();
  const originalPassword = 'Test1234';
  await signUp({
    appId: APP, email, password: originalPassword, username: `u-${counter}`,
    consentVersion: '2026-07-29', deviceName: 'test-runner',
  });
  await requestPasswordReset(APP, email);
  const code = (await latestResetCode(email))!;
  const { resetToken } = await verifyPasswordResetCode(APP, email, code);
  await assert.rejects(
    resetPassword(APP, resetToken, 'allletters'),
    (error: { code: string }) => error.code === 'VALIDATION_ERROR',
  );
  await resetPassword(APP, resetToken, 'Changed123');
  await assert.rejects(
    signIn({
      appId: APP, identifier: email, password: originalPassword, deviceName: 'test-runner',
    }),
    (error: { code: string }) => error.code === 'INVALID_CREDENTIALS',
  );
  const result = await signIn({
    appId: APP, identifier: email, password: 'Changed123', deviceName: 'test-runner',
  });
  assert.equal(result.user.email, email);
});
