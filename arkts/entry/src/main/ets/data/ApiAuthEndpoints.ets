// 认证与账号资料端点——从 ApiClient.ets 拆出以服从 CI 350 行硬上限。
// ArkTS 无 partial class / extension，端点实现为收 transport 的自由函数，
// ApiClient 以薄委托保持原有调用面不变。
import http from '@ohos.net.http'
import { ApiTransport, ProfileUpdateBody, SocialSignInInput } from './ApiTransport'
import {
  AppUser,
  AuthPayload,
  PhoneCodeInput,
  PhoneVerifyInput,
  SignInInput,
  SignUpInput
} from '../domain/Models'

export function signIn(
  transport: ApiTransport, identifier: string, password: string
): Promise<AuthPayload> {
  const input: SignInInput = { identifier, password, deviceName: 'HarmonyOS · MobileUI' }
  return transport.request<AuthPayload>('/api/v1/auth/sign-in', http.RequestMethod.POST, input)
}

export function signUp(
  transport: ApiTransport,
  email: string,
  password: string,
  username: string,
  consentVersion: string
): Promise<AuthPayload> {
  const input: SignUpInput = {
    email,
    password,
    username,
    consentVersion,
    deviceName: 'HarmonyOS · MobileUI'
  }
  return transport.request<AuthPayload>('/api/v1/auth/sign-up', http.RequestMethod.POST, input)
}

export function verifyEmail(transport: ApiTransport, email: string, code: string): Promise<boolean> {
  return transport.request<Record<string, boolean>>(
    '/api/v1/auth/verify-email',
    http.RequestMethod.POST,
    { email, code }
  ).then(result => result['verified'] === true)
}

export function resendEmailVerification(transport: ApiTransport, email: string): Promise<boolean> {
  return transport.request<Record<string, boolean>>(
    '/api/v1/auth/verify-email/resend',
    http.RequestMethod.POST,
    { email }
  ).then(result => result['accepted'] === true)
}

export function signOut(transport: ApiTransport): Promise<boolean> {
  return transport.request<Record<string, boolean>>(
    '/api/v1/auth/sign-out',
    http.RequestMethod.POST
  ).then(result => result['signedOut'] === true)
}

export function signOutAll(transport: ApiTransport): Promise<boolean> {
  return transport.request<Record<string, boolean>>(
    '/api/v1/auth/sign-out-all',
    http.RequestMethod.POST
  ).then(result => result['signedOut'] === true)
}

export function requestPhoneCode(transport: ApiTransport, phone: string): Promise<boolean> {
  const input: PhoneCodeInput = { phone }
  return transport.request<Record<string, boolean>>(
    '/api/v1/auth/phone/request',
    http.RequestMethod.POST,
    input
  ).then(result => result['accepted'] === true)
}

export function verifyPhoneCode(
  transport: ApiTransport, phone: string, code: string
): Promise<AuthPayload> {
  const input: PhoneVerifyInput = {
    phone,
    code,
    deviceName: 'HarmonyOS · MobileUI'
  }
  return transport.request<AuthPayload>(
    '/api/v1/auth/phone/verify',
    http.RequestMethod.POST,
    input
  )
}

export function socialSignIn(
  transport: ApiTransport,
  provider: string,
  idToken: string,
  authorizationCode: string,
  redirectUri: string,
  codeVerifier: string
): Promise<AuthPayload> {
  const body: SocialSignInInput = {
    provider,
    deviceName: 'HarmonyOS · MobileUI'
  }
  if (idToken.length > 0) body.idToken = idToken
  if (authorizationCode.length > 0) body.authorizationCode = authorizationCode
  if (redirectUri.length > 0) body.redirectUri = redirectUri
  if (codeVerifier.length > 0) body.codeVerifier = codeVerifier
  return transport.request<AuthPayload>(
    '/api/v1/auth/social', http.RequestMethod.POST, body
  )
}

export function requestPasswordReset(transport: ApiTransport, email: string): Promise<boolean> {
  return transport.request<Record<string, string | number | boolean>>(
    '/api/v1/auth/password/forgot', http.RequestMethod.POST, { email }
  ).then(result => result['accepted'] === true)
}

export function verifyPasswordReset(
  transport: ApiTransport, email: string, code: string
): Promise<string> {
  return transport.request<Record<string, string | number>>(
    '/api/v1/auth/password/verify', http.RequestMethod.POST, { email, code }
  ).then(result => String(result['resetToken'] ?? ''))
}

export function resetPassword(
  transport: ApiTransport, resetToken: string, newPassword: string
): Promise<boolean> {
  return transport.request<Record<string, boolean>>(
    '/api/v1/auth/password/reset', http.RequestMethod.POST,
    { resetToken, newPassword }
  ).then(result => result['changed'] === true)
}

export function saveSettings(
  transport: ApiTransport,
  patch: Record<string, string | number | boolean>
): Promise<Record<string, string | number | boolean>> {
  return transport.request<Record<string, string | number | boolean>>(
    '/api/v1/me/settings',
    http.RequestMethod.PUT,
    patch
  )
}

export function changePassword(
  transport: ApiTransport, currentPassword: string, newPassword: string
): Promise<boolean> {
  return transport.request<Record<string, boolean>>(
    '/api/v1/me/change-password',
    http.RequestMethod.POST,
    { currentPassword, newPassword }
  ).then(result => result['changed'] === true)
}

export function updateProfile(
  transport: ApiTransport,
  displayName: string,
  bio: string,
  avatarUrl: string | null
): Promise<AppUser> {
  // 空串统一转 null（服务端 schema 拒绝 ''，未设置头像就是 null）。
  const normalizedAvatar = avatarUrl !== null && avatarUrl.length === 0 ? null : avatarUrl
  const body: ProfileUpdateBody = {
    displayName,
    bio,
    avatarUrl: normalizedAvatar
  }
  return transport.request<AppUser>(
    '/api/v1/me/profile',
    http.RequestMethod.PUT,
    body
  )
}
