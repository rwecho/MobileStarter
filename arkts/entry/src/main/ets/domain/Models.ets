export interface BrandConfig {
  appName: string
  tagline: string
  primaryColor: string
}

export interface SplashConfig {
  id: string
  title: string
  description: string
  badge: string
  actionLabel: string
  imageUrl: string | null
  skippable: boolean
  durationSeconds: number
}

export interface MembershipTier {
  id: string
  name: string
  summary: string
  recommended: boolean
  accent: string
  entitlements: string[]
}

export interface BillingPlan {
  id: string
  tierId: string
  name: string
  interval: string
  priceMinor: number
  currency: string
  provider: string
}

export interface LegalDocument {
  type: string
  locale: string
  revision: string
  title: string
  content: string
  requiresReconsent: boolean
}

export interface SettingPolicy {
  visibility: string
  mutability: string
}

export interface RuntimeConfig {
  schemaVersion: number
  version: number
  cacheTtlSeconds: number
  brand: BrandConfig
  splash: SplashConfig
  legal: LegalDocument[]
  settingsPolicy: Record<string, SettingPolicy>
  features: Record<string, boolean>
  tiers: MembershipTier[]
  plans: BillingPlan[]
}

export interface UsageScreen {
  screenId: string
  views: number
  durationMs: number
}

export interface UsageSummary {
  sessions: number
  screenViews: number
  activeMinutes: number
  screens: UsageScreen[]
}

export interface CouponView {
  id: string
  code: string
  title: string
  discountLabel: string
  expiresAt: string | null
  usedAt: string | null
  createdAt: string
}

export interface ReferralView {
  code: string
  invited: number
  shareUrl: string
}

export interface SessionView {
  id: string
  deviceName: string
  current: boolean
  createdAt: string
  lastSeenAt: string
}

export interface OrderView {
  id: string
  planId: string
  status: string
  amountMinor: number
  currency: string
  provider: string
  createdAt: string
  completedAt: string | null
}

export interface NotificationView {
  id: string
  type: string
  title: string
  body: string
  route: string | null
  readAt: string | null
  createdAt: string
}

export interface AppUser {
  id: string
  email: string
  username: string
  displayName: string
  bio: string
  avatarUrl: string | null
  tierId: string
  settings: Record<string, string | number | boolean>
  createdAt: string
}

export interface BootstrapPayload {
  config: RuntimeConfig
  user: AppUser | null
  authProviders: Record<string, boolean>
  authProviderPolicy: Record<string, boolean>
  serverTime: string
  apiVersion: string
}

export interface AuthPayload {
  token: string
  user: AppUser
}

export interface ApiEnvelope<T> {
  data: T
}

export interface ApiErrorBody {
  error: ApiError
}

export interface ApiError {
  code: string
  message: string
  retryable: boolean
  traceId: string
}

export interface SignInInput {
  identifier: string
  password: string
  deviceName: string
}

export interface SignUpInput {
  email: string
  password: string
  deviceName: string
  username: string
}

export interface DeleteAccountInput {
  password: string
  confirmation: string
}

export interface PhoneCodeInput {
  phone: string
}

export interface PhoneVerifyInput extends PhoneCodeInput {
  code: string
  deviceName: string
}

export interface FeedbackInput {
  category: string
  title: string
  body: string
  rating: number
}
