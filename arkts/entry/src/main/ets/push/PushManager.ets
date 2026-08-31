import { pushService } from '@kit.PushKit'
import { apiClient } from '../data/ApiClient'
import { telemetry } from '../telemetry/Telemetry'

// 推送基线：Push Kit 令牌获取 + 服务端绑定。
// HarmonyOS 推送走系统通知通道，无前台 onMessage 等价物（点按消息经
// want/深链进入，由导航层统一处理）；AGC 未开通推送服务时 getToken 抛错，
// 静默降级为无推送，不影响登录流程。
let cachedToken: string = ''

export async function registerPushTokenAction(): Promise<void> {
  try {
    cachedToken = await pushService.getToken()
    await apiClient.registerPushToken(cachedToken)
  } catch (error) {
    telemetry.report(error as Error)
  }
}

export async function unregisterPushTokenAction(): Promise<void> {
  if (cachedToken.length === 0) {
    return
  }
  const token = cachedToken
  cachedToken = ''
  try {
    await apiClient.unregisterPushToken(token)
  } catch (error) {
    telemetry.report(error as Error)
  }
}
