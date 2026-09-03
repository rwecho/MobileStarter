import { describe, it, beforeEach, mock } from 'node:test';
import assert from 'node:assert/strict';
import { writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

// 支付凭证注册表：文件条目覆盖 env 兜底 + webhook 反查路由。
// 文件路径与 env 全部注入，测试间互不污染。

const REG = await import('../src/server/payment-apps.ts');

function withEnv(name: string, value: string | undefined, fn: () => void | Promise<void>) {
  const old = process.env[name];
  if (value === undefined) delete process.env[name];
  else process.env[name] = value;
  return Promise.resolve(fn()).finally(() => {
    if (old === undefined) delete process.env[name];
    else process.env[name] = old;
  });
}

describe('payment-apps registry', () => {
  it('env 兜底：无文件注册表时读环境变量', async () => {
    await withEnv('PAYMENTS_CONFIG_FILE', join(tmpdir(), `no-such-${Date.now()}.json`), async () => {
      await withEnv('APPLE_BUNDLE_ID', 'tech.demo.app', async () => {
        await withEnv('APPLE_APP_APPLE_ID', '123', async () => {
          REG.__resetForTest();
          const pay = REG.paymentsForApp('any-app');
          assert.equal(pay.apple?.bundleId, 'tech.demo.app');
          assert.equal(REG.appIdForAppleBundle('tech.demo.app'), 'default');
          assert.equal(REG.appIdForAppleBundle('tech.other.app'), undefined);
        });
      });
    });
  });

  it('文件条目：按 app_id 精确取用，其他 app 不受影响', async () => {
    const dir = mkdtempSync(join(tmpdir(), 'payreg-'));
    const file = join(dir, 'payments.json');
    writeFileSync(file, JSON.stringify({
      apps: {
        geekread: { hms: { clientId: 'g-cid', clientSecret: 'g-sec', appId: 'g-hms-app' } },
      },
    }));
    await withEnv('PAYMENTS_CONFIG_FILE', file, async () => {
      await withEnv('HMS_CLIENT_ID', undefined, async () => {
        REG.__resetForTest();
        const geek = REG.paymentsForApp('geekread');
        assert.equal(geek.hms?.clientId, 'g-cid');
        assert.equal(geek.hms?.appId, 'g-hms-app');
        // 未注册的 app 没有 HMS 凭证 → 适配器会抛 503（此处只验解析层）
        assert.equal(REG.paymentsForApp('someone-else').hms, undefined);
      });
    });
    rmSync(dir, { recursive: true, force: true });
  });

  it('文件覆盖 env：同 provider 整节替换', async () => {
    const dir = mkdtempSync(join(tmpdir(), 'payreg-'));
    const file = join(dir, 'payments.json');
    writeFileSync(file, JSON.stringify({
      apps: { lofi: { google: { packageName: 'tech.lofi.prod', serviceAccountFile: 'certs/a.json' } } },
    }));
    await withEnv('PAYMENTS_CONFIG_FILE', file, async () => {
      await withEnv('GOOGLE_PACKAGE_NAME', 'tech.lofi.dev', async () => {
        REG.__resetForTest();
        assert.equal(REG.paymentsForApp('lofi').google?.packageName, 'tech.lofi.prod');
        assert.equal(REG.appIdForGooglePackage('tech.lofi.prod'), 'lofi');
        // env 兜底包名仍然可达，反查归为 'default'（单 app 部署形态）
        assert.equal(REG.appIdForGooglePackage('tech.lofi.dev'), 'default');
      });
    });
    rmSync(dir, { recursive: true, force: true });
  });

  it('mtime 前进后重读：内容更新对调用方可见', async () => {
    const dir = mkdtempSync(join(tmpdir(), 'payreg-'));
    const file = join(dir, 'payments.json');
    writeFileSync(file, JSON.stringify({ apps: { a1: { hms: { clientId: 'x', clientSecret: 'y', appId: 'z' } } } }));
    await withEnv('PAYMENTS_CONFIG_FILE', file, async () => {
      REG.__resetForTest();
      assert.equal(REG.paymentsForApp('a1').hms?.clientId, 'x');
      // 显式把 mtime 推前 10ms，模拟缓存过期后的热更新
      const future = new Date(Date.now() + 10);
      const { utimesSync } = await import('node:fs');
      writeFileSync(file, JSON.stringify({ apps: { a1: { hms: { clientId: 'x2', clientSecret: 'y', appId: 'z' } } } }));
      utimesSync(file, future, future);
      assert.equal(REG.paymentsForApp('a1').hms?.clientId, 'x2');
    });
    rmSync(dir, { recursive: true, force: true });
  });

  it('注册表损坏：视为空表不抛异常', async () => {
    const dir = mkdtempSync(join(tmpdir(), 'payreg-'));
    const file = join(dir, 'payments.json');
    writeFileSync(file, '{ not json !!!');
    await withEnv('PAYMENTS_CONFIG_FILE', file, async () => {
      await withEnv('APPLE_BUNDLE_ID', 'tech.demo.app', async () => {
        await withEnv('APPLE_APP_APPLE_ID', '1', async () => {
          REG.__resetForTest();
          const pay = REG.paymentsForApp('any');
          assert.equal(pay.apple?.bundleId, 'tech.demo.app');
          assert.equal(REG.appIdForAppleBundle('tech.demo.app'), 'default');
        });
      });
    });
    rmSync(dir, { recursive: true, force: true });
  });
});
