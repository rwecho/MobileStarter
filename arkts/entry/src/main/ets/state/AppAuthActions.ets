// AppStore 的认证/会话动作——从 AppStore.ets 拆出以服从 CI 350 行硬上限。
// ArkTS 无 partial class / extension，动作实现为收 store 的自由函数，
// AppStore 以薄委托保持原有调用面不变。
import { apiClient, ApiFailure } from '../data/ApiClient'
import { localStore } from '../data/LocalStore'
import { AuthPayload } from '../domain/Models'
import { AppRoute } from '../navigation/AppRoute'
import { AppStore } from './AppStore'

async function authenticate(
  store: AppStore, operation: () => Promise<AuthPayload>
): Promise<boolean> {
  if (store.busy) {
    return false
  }
  store.busy = true
  try {
    const payload = await operation()
    localStore.saveToken(payload.token)
    apiClient.setToken(payload.token)
    localStore.saveRefreshToken(payload.refreshToken)
    apiClient.setRefreshToken(payload.refreshToken)
    store.user = payload.user
    store.signedIn = true
    store.online = true
    store.lastAuthError = ''
    return true
  } catch (error) {
    store.lastAuthError = authErrorMessage(store, error)
    return false
  } finally {
    store.busy = false
  }
}

function authErrorMessage(store: AppStore, error: Error): string {
  if (error instanceof ApiFailure) {
    return error.message
  }
  store.online = false
  return '网络连接失败，请稍后重试'
}

async function performBooleanRequest(
  store: AppStore, operation: () => Promise<boolean>
): Promise<boolean> {
  if (store.busy) return false
  store.busy = true
  try {
    return await operation()
  } catch (error) {
    store.showApiError(error)
    return false
  } finally {
    store.busy = false
  }
}

export function signInAction(store: AppStore, email: string, password: string): Promise<boolean> {
  return authenticate(store, () => apiClient.signIn(email, password))
}

export function signUpAction(
  store: AppStore, email: string, password: string, username: string, consentVersion: string
): Promise<boolean> {
  return authenticate(store, () => apiClient.signUp(email, password, username, consentVersion))
}

export async function verifyEmailAction(store: AppStore, code: string): Promise<boolean> {
  if (store.user === null || store.user.email === null) return false
  try {
    const verified = await apiClient.verifyEmail(store.user.email, code)
    if (verified) store.user.emailVerified = true
    return verified
  } catch (error) {
    store.showApiError(error)
    return false
  }
}

export function requestPhoneCodeAction(store: AppStore, phone: string): Promise<boolean> {
  return performBooleanRequest(store, () => apiClient.requestPhoneCode(phone))
}

export function verifyPhoneCodeAction(
  store: AppStore, phone: string, code: string
): Promise<boolean> {
  return authenticate(store, () => apiClient.verifyPhoneCode(phone, code))
}

export function socialSignInAction(
  store: AppStore,
  provider: string,
  idToken: string,
  authorizationCode: string,
  redirectUri: string,
  codeVerifier: string
): Promise<boolean> {
  return authenticate(store, () => apiClient.socialSignIn(
    provider, idToken, authorizationCode, redirectUri, codeVerifier
  ))
}

export function requestPasswordResetAction(store: AppStore, email: string): Promise<boolean> {
  return performBooleanRequest(store, async () => {
    const accepted = await apiClient.requestPasswordReset(email)
    if (accepted) store.recoveryEmail = email
    return accepted
  })
}

export function verifyPasswordResetAction(store: AppStore, code: string): Promise<boolean> {
  return performBooleanRequest(store, async () => {
    store.resetToken = await apiClient.verifyPasswordReset(store.recoveryEmail, code)
    return store.resetToken.length > 0
  })
}

export function resetPasswordAction(store: AppStore, newPassword: string): Promise<boolean> {
  return performBooleanRequest(store, async () => {
    const changed = await apiClient.resetPassword(store.resetToken, newPassword)
    if (changed) {
      store.recoveryEmail = ''
      store.resetToken = ''
    }
    return changed
  })
}

export async function signOutAction(store: AppStore): Promise<void> {
  try {
    await apiClient.signOut()
  } catch (error) {
    store.online = false
  }
  clearLocalSession(store)
  store.signedIn = false
  store.user = null
}

export async function signOutAllAction(store: AppStore): Promise<void> {
  try {
    await apiClient.signOutAll()
  } catch (error) {
    store.online = false
  }
  clearLocalSession(store)
  store.signedIn = false
  store.user = null
}

export function clearLocalSession(store: AppStore): void {
  localStore.saveToken('')
  localStore.saveRefreshToken('')
  apiClient.setToken('')
  apiClient.setRefreshToken('')
}

export function handleSessionExpiredAction(store: AppStore): void {
  clearLocalSession(store)
  store.signedIn = false
  store.user = null
  store.replaceAll(AppRoute.SignIn)
}
