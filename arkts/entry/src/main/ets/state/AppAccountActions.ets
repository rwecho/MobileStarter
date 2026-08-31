// AppStore 的账号/设置/客服动作——从 AppStore.ets 拆出以服从 CI 350 行硬上限。
// ArkTS 无 partial class / extension，动作实现为收 store 的自由函数，
// AppStore 以薄委托保持原有调用面不变。
import { apiClient } from '../data/ApiClient'
import { localStore } from '../data/LocalStore'
import { AppRoute } from '../navigation/AppRoute'
import { AppStore } from './AppStore'
import { clearLocalSession } from './AppAuthActions'

export async function saveSettingAction(
  store: AppStore, key: string, value: string | number | boolean
): Promise<boolean> {
  if (!store.signedIn || store.busy) {
    return false
  }
  store.busy = true
  const patch: Record<string, string | number | boolean> = {}
  patch[key] = value
  if (typeof value !== 'boolean') localStore.savePreference(key, value)
  if (store.user !== null) {
    store.user.settings[key] = value
  }
  store.applyPreferences()
  try {
    const settings = await apiClient.saveSettings(patch)
    if (store.user !== null) {
      store.user.settings = settings
    }
    cacheUserPreferences(store)
    store.applyPreferences()
    store.online = true
    store.showToast('设置已同步到服务端')
    return true
  } catch (error) {
    store.showApiError(error)
    return false
  } finally {
    store.busy = false
  }
}

export async function deleteAccountAction(store: AppStore, password: string): Promise<boolean> {
  if (!store.signedIn || store.busy) {
    return false
  }
  store.busy = true
  try {
    if (!await apiClient.deleteAccount(password)) {
      return false
    }
    clearLocalSession(store)
    store.signedIn = false
    store.user = null
    store.showToast('账号已永久删除')
    return true
  } catch (error) {
    store.showApiError(error)
    return false
  } finally {
    store.busy = false
  }
}

export async function changePasswordAction(
  store: AppStore, currentPassword: string, newPassword: string
): Promise<boolean> {
  if (!store.signedIn || store.busy) return false
  store.busy = true
  try {
    if (!await apiClient.changePassword(currentPassword, newPassword)) return false
    clearLocalSession(store)
    store.signedIn = false
    store.user = null
    store.showToast('密码已修改，请重新登录')
    return true
  } catch (error) {
    store.showApiError(error)
    return false
  } finally {
    store.busy = false
  }
}

export async function updateProfileAction(
  store: AppStore, displayName: string, bio: string, avatarUrl: string | null
): Promise<boolean> {
  if (!store.signedIn || store.busy) return false
  store.busy = true
  try {
    store.user = await apiClient.updateProfile(displayName, bio, avatarUrl)
    store.showToast('个人资料已同步到服务端')
    return true
  } catch (error) {
    store.showApiError(error)
    return false
  } finally {
    store.busy = false
  }
}

export async function submitFeedbackAction(
  store: AppStore,
  title: string,
  body: string,
  category: string = 'suggestion',
  rating: number = 5
): Promise<boolean> {
  if (store.busy) return false
  store.busy = true
  try {
    const submitted = await apiClient.submitFeedback(title, body, category, rating)
    if (submitted) store.showToast('意见反馈已提交')
    return submitted
  } catch (error) {
    store.showApiError(error)
    return false
  } finally {
    store.busy = false
  }
}

export async function createTicketAction(
  store: AppStore, category: string, severity: string, subject: string, message: string
): Promise<boolean> {
  if (store.busy) return false
  store.busy = true
  try {
    const created = await apiClient.createTicket({ category, severity, subject, message })
    await store.remote.openTicket(created.id)
    store.navigate(AppRoute.SupportTicket)
    store.showToast('工单已提交')
    return true
  } catch (error) {
    store.showApiError(error)
    return false
  } finally {
    store.busy = false
  }
}

export async function replyTicketAction(store: AppStore, message: string): Promise<boolean> {
  const detail = store.remote.ticketDetailState.data
  if (detail === undefined || store.busy) return false
  store.busy = true
  try {
    const sent = await apiClient.reply(detail.id, message)
    store.remote.appendReply(sent)
    return true
  } catch (error) {
    store.showApiError(error)
    return false
  } finally {
    store.busy = false
  }
}

// 服务端 settings → 本地偏好快照（theme/language/textScale 持久化）。
export function cacheUserPreferences(store: AppStore): void {
  const settings = store.user?.settings
  if (settings === undefined) return
  const theme = settings['theme']
  const language = settings['language']
  const textScale = settings['textScale']
  if (typeof theme === 'string') localStore.savePreference('theme', theme)
  if (typeof language === 'string') localStore.savePreference('language', language)
  if (typeof textScale === 'number') localStore.savePreference('textScale', textScale)
}
