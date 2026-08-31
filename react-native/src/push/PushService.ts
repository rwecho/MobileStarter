/**
 * 推送基线：FCM/APNs 令牌注册 + 前台消息转发。
 * messaging 依赖原生 Firebase 配置（google-services / GoogleService-Info），
 * 与 Telemetry 的 firebase 三件套同策略：动态 import + 失败静默降级，
 * web / 未配置原生工程时推送不可用但不阻塞登录流程。
 */
import { apiClient } from '../data/apiClient';
import { telemetry } from '../telemetry/Telemetry';

// @react-native-firebase/messaging 的最小使用面（与 IAP 懒加载同一模式）。
interface RemoteMessageLike {
  notification?: { title?: string; body?: string };
}
interface MessagingApp {
  requestPermission(): Promise<number>;
  getToken(): Promise<string>;
  deleteToken(): Promise<void>;
  onTokenRefresh(listener: (token: string) => void): () => void;
  onMessage(listener: (message: RemoteMessageLike) => void): () => void;
}
type MessagingFactory = () => MessagingApp;

let messaging: MessagingFactory | null = null;
let loaded = false;
async function loadMessaging(): Promise<MessagingFactory | null> {
  if (loaded) return messaging;
  loaded = true;
  try {
    const module = await import('@react-native-firebase/messaging');
    // 类型层未声明 default 导出（运行时存在），与 IAP 同样走最小使用面断言。
    messaging = (module as unknown as { default?: MessagingFactory }).default ?? null;
  } catch (error) {
    telemetry.report(error instanceof Error ? error : new Error('messaging unavailable'));
  }
  return messaging;
}

let unsubscribe: (() => void) | null = null;
let token: string | null = null;

export async function startPush(onForeground: (message: string) => void): Promise<void> {
  const factory = await loadMessaging();
  if (!factory || unsubscribe) return;
  try {
    await factory().requestPermission();
  } catch {
    return; // 权限被拒：推送降级为不可用，不重复注册
  }
  const instance = factory();
  token = await instance.getToken();
  await apiClient.registerPushToken(token);
  const tokenSub = instance.onTokenRefresh((next) => {
    token = next;
    apiClient.registerPushToken(next).catch((error) => {
      telemetry.report(error instanceof Error ? error : new Error('token refresh failed'));
    });
  });
  const messageSub = instance.onMessage((message) => {
    const body = message.notification?.body;
    if (body) onForeground(body);
  });
  unsubscribe = () => {
    tokenSub();
    messageSub();
  };
}

export async function stopPush(): Promise<void> {
  const factory = await loadMessaging();
  unsubscribe?.();
  unsubscribe = null;
  if (!factory || !token) return;
  const lastToken = token;
  token = null;
  try {
    await apiClient.unregisterPushToken(lastToken);
    await factory().deleteToken();
  } catch (error) {
    telemetry.report(error instanceof Error ? error : new Error('push unregister failed'));
  }
}
