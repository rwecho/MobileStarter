export type PublicUser = Readonly<{
  id: string;
  email: string;
  username: string;
  displayName: string;
  bio: string;
  avatarUrl: string | null;
  tierId: string;
  settings: Readonly<Record<string, string | boolean | number>>;
  emailVerified: boolean;
  consentVersion: string | null;
  createdAt: string;
  // 是否有真实邮箱（false=华为/手机号自动生成的伪邮箱，客户端不应展示 email）
  hasEmail: boolean;
}>;

export type SessionView = Readonly<{
  id: string;
  deviceName: string;
  current: boolean;
  createdAt: string;
  lastSeenAt: string;
}>;
