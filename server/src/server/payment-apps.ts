import { existsSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';

/**
 * 多 app 支付凭证注册表。
 *
 * 共享 auth 底座上多个 app 各有自己的商店凭证（bundleId/packageName/HMS appId、
 * 密钥文件、环境）。凭证来源两层：
 *
 *   1. 文件注册表 `certs/payments.json`（PAYMENTS_CONFIG_FILE 可覆盖路径）——
 *      按 app_id 分节，文件条目整体替换同 provider 的 env 兜底值；
 *   2. 环境变量兜底（APPLE_x / GOOGLE_x / HMS_x 系列）——单 app 部署的原始
 *      形态，只对没有文件条目的 app 生效，保证存量部署零迁移。
 *
 * 反查表（bundleId/packageName → app_id）供 webhook 路由：商店回调不带
 * x-app-id，靠验签前的路由读出归属 app 再选凭证做真实验证。
 */

export type ApplePaymentsConfig = Readonly<{
  bundleId: string;
  appAppleId: number;
  issuerId: string;
  keyId: string;
  privateKeyFile: string;
  /** Production / Sandbox / LocalTesting / Xcode；Production 与 Sandbox 互为兜底 */
  environment: string;
}>;

export type GooglePaymentsConfig = Readonly<{
  packageName: string;
  serviceAccountFile: string;
}>;

export type HmsPaymentsConfig = Readonly<{
  clientId: string;
  clientSecret: string;
  /** HMS 应用 ID（订单验证 URL 中的应用标识，非 auth 底座的 app_id） */
  appId: string;
  /** 区域订单服务，默认 https://orders-dre.iap.hicloud.com */
  ordersUrl?: string;
  /** HarmonyOS NEXT 应用包名——webhook 反查路由 + 通知归属校验 */
  packageName?: string;
  /** HarmonyOS NEXT 服务端 API（订单/订阅状态查询、发货确认）JWT 签名私钥（AGC 下载的 .p8） */
  privateKeyFile?: string;
  /** JWT header.kid——AGC「配置密钥」页的密钥 ID */
  keyId?: string;
  /** JWT payload.iss——AGC「配置密钥」页的密钥颁发者 ID */
  issuerId?: string;
  /** 华为 CBG Root CA G2 根证书（PEM/DER）——通知 JWS 的 x5c 证书链锚点 */
  rootCaFile?: string;
  /** HarmonyOS NEXT 订单/订阅服务站点，默认 https://iap.cloud.huawei.com（中国站） */
  serverApiUrl?: string;
}>;

export type AppPayments = Readonly<{
  apple?: ApplePaymentsConfig;
  google?: GooglePaymentsConfig;
  hms?: HmsPaymentsConfig;
}>;

const DEFAULT_CONFIG_FILE = join(process.cwd(), 'certs', 'payments.json');

interface FileRegistry {
  cache: Record<string, AppPayments> | null;
  mtimeMs: number;
  path: string;
}

const registry: FileRegistry = { cache: null, mtimeMs: 0, path: '' };

function loadFileRegistry(): Record<string, AppPayments> {
  const path = process.env.PAYMENTS_CONFIG_FILE ?? DEFAULT_CONFIG_FILE;
  if (!existsSync(path)) {
    registry.cache = {};
    registry.path = path;
    return registry.cache;
  }
  // mtime 变化才重读：测试与热更新友好，避免每个请求都吃一次磁盘 IO
  const mtimeMs = mtimeOf(path);
  if (registry.cache && registry.path === path && registry.mtimeMs === mtimeMs) {
    return registry.cache;
  }
  try {
    const parsed = JSON.parse(readFileSync(path, 'utf8')) as { apps?: Record<string, AppPayments> };
    registry.cache = parsed.apps ?? {};
    registry.path = path;
    registry.mtimeMs = mtimeMs;
  } catch {
    // 注册表损坏不应拖垮支付：视为空表并保留旧缓存语义（下次成功解析再替换）
    registry.cache = registry.cache ?? {};
  }
  return registry.cache;
}

function mtimeOf(path: string): number {
  try {
    return statSync(path).mtimeMs;
  } catch {
    return 0;
  }
}

function envAppleConfig(): ApplePaymentsConfig | undefined {
  const bundleId = process.env.APPLE_BUNDLE_ID;
  const appAppleId = process.env.APPLE_APP_APPLE_ID;
  if (!bundleId || !appAppleId) return undefined;
  return {
    bundleId,
    appAppleId: Number(appAppleId),
    issuerId: process.env.APPLE_ISSUER_ID ?? '',
    keyId: process.env.APPLE_KEY_ID ?? '',
    privateKeyFile: process.env.APPLE_PRIVATE_KEY_FILE ?? '',
    environment: process.env.APPLE_ENVIRONMENT ?? 'Sandbox',
  };
}

function envGoogleConfig(): GooglePaymentsConfig | undefined {
  const packageName = process.env.GOOGLE_PACKAGE_NAME;
  if (!packageName) return undefined;
  return {
    packageName,
    serviceAccountFile: process.env.GOOGLE_SERVICE_ACCOUNT_FILE ?? '',
  };
}

function envHmsConfig(): HmsPaymentsConfig | undefined {
  const appId = process.env.HMS_APP_ID;
  if (!appId) return undefined;
  // 两种形态任一即可：旧 Android HMS（OAuth2 client_credentials）或
  // HarmonyOS NEXT 服务端 API（IAP 密钥 JWT ES256）。NEXT 形态不要求 clientId/Secret。
  const legacyReady = process.env.HMS_CLIENT_ID && process.env.HMS_CLIENT_SECRET;
  const nextReady = process.env.HMS_IAP_PRIVATE_KEY_FILE && process.env.HMS_IAP_KEY_ID;
  if (!legacyReady && !nextReady) return undefined;
  return {
    clientId: process.env.HMS_CLIENT_ID ?? '',
    clientSecret: process.env.HMS_CLIENT_SECRET ?? '',
    appId,
    ordersUrl: process.env.HMS_IAP_ORDERS_URL,
    packageName: process.env.HMS_PACKAGE_NAME,
    privateKeyFile: process.env.HMS_IAP_PRIVATE_KEY_FILE,
    keyId: process.env.HMS_IAP_KEY_ID,
    issuerId: process.env.HMS_IAP_ISSUER_ID,
    rootCaFile: process.env.HMS_ROOT_CA_FILE,
    serverApiUrl: process.env.HMS_IAP_SERVER_URL,
  };
}

/** 取指定 app 的支付凭证：文件条目覆盖 env 兜底（按 provider 整节替换）。 */
export function paymentsForApp(appId: string): AppPayments {
  const fromFile = loadFileRegistry()[appId] ?? {};
  return {
    apple: fromFile.apple ?? envAppleConfig(),
    google: fromFile.google ?? envGoogleConfig(),
    hms: fromFile.hms ?? envHmsConfig(),
  };
}

/** webhook 反查：Apple bundleId → auth app_id（env 兜底 app 优先级最低）。 */
export function appIdForAppleBundle(bundleId: string): string | undefined {
  for (const [appId, pay] of Object.entries(loadFileRegistry())) {
    if (pay.apple?.bundleId === bundleId) return appId;
  }
  const env = envAppleConfig();
  return env?.bundleId === bundleId ? 'default' : undefined;
}

/** webhook 反查：Google packageName → auth app_id。 */
export function appIdForGooglePackage(packageName: string): string | undefined {
  for (const [appId, pay] of Object.entries(loadFileRegistry())) {
    if (pay.google?.packageName === packageName) return appId;
  }
  const env = envGoogleConfig();
  return env?.packageName === packageName ? 'default' : undefined;
}

/** webhook 反查：HMS packageName → auth app_id（通知 JWS 解码后按归属路由凭证）。 */
export function appIdForHmsPackage(packageName: string): string | undefined {
  for (const [appId, pay] of Object.entries(loadFileRegistry())) {
    if (pay.hms?.packageName === packageName) return appId;
  }
  const env = envHmsConfig();
  return env?.packageName === packageName ? 'default' : undefined;
}

/**
 * 全注册表只有一个 apple app 时返回它（含 env 兜底形态）；供 TEST 测试
 * 通知的启发式路由——TEST 载荷没有 bundleId。
 */
export function soleAppleAppId(): string | undefined {
  const entries = Object.entries(loadFileRegistry()).filter(([, pay]) => pay.apple);
  const withApple = entries.map(([appId]) => appId);
  if (withApple.length === 1) return withApple[0];
  if (withApple.length === 0 && envAppleConfig()) return 'default';
  return undefined;
}

/**
 * webhook 路由的兜底归属：反查不到时的处理交给调用方（默认 app 或拒绝）。
 * env 单 app 部署的 app_id 从 APPLE/GOOGLE 配置无法推知（历史上无此概念），
 * 用 'default' 占位——订单查找按 store_transaction_id 全局进行，'default'
 * 只影响选凭证，不影响权益归属。
 */
export const WEBHOOK_DEFAULT_APP = 'default';

/** 测试钩子：清空文件注册表缓存（env 是进程级读取，无需清理）。 */
export function __resetForTest(): void {
  registry.cache = null;
  registry.mtimeMs = 0;
  registry.path = '';
}
