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
}>;

export type SessionView = Readonly<{
  id: string;
  deviceName: string;
  current: boolean;
  createdAt: string;
  lastSeenAt: string;
}>;
