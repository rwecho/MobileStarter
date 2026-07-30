export type SplashCampaign = Readonly<{
  id: string;
  title: string;
  description: string;
  badge: string;
  actionLabel: string;
  imageUrl: string | null;
  skippable: boolean;
  durationSeconds: number;
}>;

export type Entitlement = Readonly<{
  key: string;
  label: string;
  description: string;
}>;

export type MembershipTier = Readonly<{
  id: string;
  name: string;
  summary: string;
  recommended: boolean;
  accent: string;
  entitlements: readonly string[];
}>;

export type BillingPlan = Readonly<{
  id: string;
  tierId: string;
  name: string;
  interval: 'month' | 'year' | 'lifetime' | 'one_time';
  priceMinor: number;
  currency: string;
  originalPriceMinor?: number;
  provider: 'mock' | 'apple' | 'google' | 'wechat' | 'alipay';
}>;

export type PasswordPolicy = Readonly<{
  minLength: number;
  maxLength: number;
  requireUppercase: boolean;
  requireLowercase: boolean;
  requireDigit: boolean;
  requireSymbol: boolean;
}>;

export type SupportConfig = Readonly<{
  enabled: boolean;
  market: string;
  dataRegion: string;
  categories: ReadonlyArray<Readonly<{ id: string; label: string }>>;
  queues: ReadonlyArray<Readonly<{
    id: string;
    market: string;
    locales: readonly string[];
    categories: readonly string[];
  }>>;
  help: ReadonlyArray<Readonly<{
    id: string;
    locale: string;
    title: string;
    body: string;
  }>>;
}>;

export type RuntimeConfig = Readonly<{
  schemaVersion: number;
  version: number;
  brand: Readonly<{
    appName: string;
    tagline: string;
    primaryColor: string;
  }>;
  splash: SplashCampaign;
  cacheTtlSeconds: number;
  telemetry: Readonly<{
    enabled: boolean;
    backendEnabled: boolean;
    firebaseMode: 'disabled' | 'client_direct' | 'server_forwarded';
    analyticsEnabled: boolean;
    crashlyticsEnabled: boolean;
  }>;
  support: SupportConfig;
  auth: Readonly<{
    providers: ReadonlyArray<Readonly<{
      id: 'password' | 'phone' | 'apple' | 'google' | 'github' | 'wechat';
      enabled: boolean;
      platforms: readonly ('ios' | 'android' | 'harmonyos' | 'web')[];
      clientIds?: Readonly<Partial<Record<'ios' | 'android' | 'harmonyos' | 'web', string>>>;
    }>>;
    passwordPolicy: PasswordPolicy;
  }>;
  legal: ReadonlyArray<Readonly<{
    type: 'privacy' | 'terms' | 'subscription';
    locale: 'zh-CN' | 'en-US';
    revision: string;
    title: string;
    content: string;
    requiresReconsent: boolean;
  }>>;
  settingsPolicy: Readonly<Record<string, Readonly<{
    visibility: 'visible' | 'hidden';
    mutability: 'user' | 'admin_locked' | 'system';
  }>>>;
  features: Readonly<Record<string, boolean>>;
  entitlements: readonly Entitlement[];
  tiers: readonly MembershipTier[];
  plans: readonly BillingPlan[];
}>;

export const defaultConfig: RuntimeConfig = {
  schemaVersion: 1,
  version: 1,
  brand: {
    appName: 'MobileStarter',
    tagline: '把灵感变成作品',
    primaryColor: '#A84444',
  },
  splash: {
    id: 'summer-create',
    title: '创作，从一个好模板开始',
    description: '专业工具、智能素材与跨端体验，都已准备就绪。',
    badge: '本周精选',
    actionLabel: '开始探索',
    imageUrl: null,
    skippable: true,
    durationSeconds: 5,
  },
  cacheTtlSeconds: 900,
  telemetry: {
    enabled: true,
    backendEnabled: true,
    firebaseMode: 'client_direct',
    analyticsEnabled: true,
    crashlyticsEnabled: true,
  },
  support: {
    enabled: true,
    market: 'global',
    dataRegion: 'us',
    categories: [
      { id: 'account', label: '账号与登录' },
      { id: 'billing', label: '会员与支付' },
      { id: 'technical', label: '功能故障' },
      { id: 'privacy', label: '隐私与数据' },
      { id: 'suggestion', label: '产品建议' },
    ],
    queues: [
      {
        id: 'china-zh',
        market: 'CN',
        locales: ['zh-CN'],
        categories: ['account', 'billing', 'technical', 'privacy', 'suggestion'],
      },
      {
        id: 'global',
        market: 'global',
        locales: ['zh-CN', 'en-US'],
        categories: ['account', 'billing', 'technical', 'privacy', 'suggestion'],
      },
    ],
    help: [
      {
        id: 'account-security',
        locale: 'zh-CN',
        title: '如何保护账号安全？',
        body: '请使用独立密码，并定期检查“登录设备”。发现异常设备后立即撤销会话并修改密码。',
      },
      {
        id: 'subscription',
        locale: 'zh-CN',
        title: '如何管理会员？',
        body: '在“会员中心”查看当前等级、可用权益、订单以及服务端下发的订阅方案。',
      },
      {
        id: 'account-security-en',
        locale: 'en-US',
        title: 'How do I protect my account?',
        body: 'Use a unique password and review signed-in devices regularly.',
      },
    ],
  },
  auth: {
    providers: [
      { id: 'password', enabled: true, platforms: ['ios', 'android', 'harmonyos', 'web'] },
      { id: 'phone', enabled: true, platforms: ['ios', 'android', 'harmonyos', 'web'] },
      { id: 'apple', enabled: true, platforms: ['ios', 'android', 'web'] },
      { id: 'google', enabled: true, platforms: ['ios', 'android', 'web'] },
      { id: 'github', enabled: true, platforms: ['ios', 'android', 'harmonyos', 'web'] },
      { id: 'wechat', enabled: false, platforms: ['ios', 'android', 'harmonyos'] },
    ],
    passwordPolicy: {
      minLength: 8,
      maxLength: 72,
      requireUppercase: false,
      requireLowercase: true,
      requireDigit: true,
      requireSymbol: false,
    },
  },
  legal: [
    {
      type: 'privacy',
      locale: 'zh-CN',
      revision: '2026-07-29',
      title: 'MobileStarter 隐私政策',
      content: '我们仅为提供账号、同步、会员和通知服务处理必要数据。',
      requiresReconsent: true,
    },
    {
      type: 'terms',
      locale: 'zh-CN',
      revision: '2026-07-29',
      title: 'MobileStarter 用户协议',
      content: '使用服务前，请阅读并理解账号、内容和订阅相关规则。',
      requiresReconsent: true,
    },
  ],
  settingsPolicy: {
    language: { visibility: 'visible', mutability: 'user' },
    appearance: { visibility: 'visible', mutability: 'user' },
    notifications: { visibility: 'visible', mutability: 'user' },
    general: { visibility: 'visible', mutability: 'user' },
    analytics: { visibility: 'visible', mutability: 'user' },
    accountDeletion: { visibility: 'visible', mutability: 'user' },
  },
  features: {
    membership: true,
    notifications: true,
    profileEditing: true,
    accountDeletion: true,
  },
  entitlements: [
    { key: 'export.hd', label: '高清导出', description: '导出 1080P 高清内容' },
    { key: 'templates.pro', label: '高级模板', description: '使用专业模板与素材' },
    { key: 'cloud.100gb', label: '100 GB 云空间', description: '跨设备同步作品' },
    { key: 'team.workspace', label: '团队空间', description: '成员与权限协作' },
  ],
  tiers: [
    {
      id: 'free',
      name: 'Free',
      summary: '基础创作工具',
      recommended: false,
      accent: '#667085',
      entitlements: [],
    },
    {
      id: 'pro',
      name: 'Pro',
      summary: '适合高频创作者',
      recommended: true,
      accent: '#A84444',
      entitlements: ['export.hd', 'templates.pro', 'cloud.100gb'],
    },
    {
      id: 'team',
      name: 'Team',
      summary: '面向团队协作',
      recommended: false,
      accent: '#3C6EAD',
      entitlements: ['export.hd', 'templates.pro', 'cloud.100gb', 'team.workspace'],
    },
  ],
  plans: [
    {
      id: 'pro-monthly',
      tierId: 'pro',
      name: 'Pro 月度',
      interval: 'month',
      priceMinor: 1800,
      currency: 'CNY',
      provider: 'mock',
    },
    {
      id: 'pro-yearly',
      tierId: 'pro',
      name: 'Pro 年度',
      interval: 'year',
      priceMinor: 16800,
      originalPriceMinor: 21600,
      currency: 'CNY',
      provider: 'mock',
    },
    {
      id: 'team-yearly',
      tierId: 'team',
      name: 'Team 年度',
      interval: 'year',
      priceMinor: 39800,
      currency: 'CNY',
      provider: 'mock',
    },
  ],
};
