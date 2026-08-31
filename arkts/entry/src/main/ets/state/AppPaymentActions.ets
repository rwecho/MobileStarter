// AppStore 的支付动作——从 AppStore.ets 拆出以服从 CI 350 行硬上限。
// ArkTS 无 partial class / extension，动作实现为收 store 的自由函数，
// AppStore 以薄委托保持原有调用面不变。
import { apiClient, ApiFailure } from '../data/ApiClient'
import { OrderStatus, PurchaseStatus } from '../domain/Models'
import { HMSIapProvider } from '../payment/HMSIapProvider'
import { MockPaymentProvider } from '../payment/MockPaymentProvider'
import { PaymentProvider } from '../payment/PaymentProvider'
import { AppStore } from './AppStore'

export async function purchaseAction(store: AppStore, planId: string): Promise<boolean> {
  store.purchaseStatus = PurchaseStatus.Loading
  store.purchaseOrder = null
  store.purchaseMessage = ''
  try {
    const idempotencyKey: string =
      `ark-${Date.now()}-${Math.random().toString(36).slice(2)}`
    const order = await apiClient.createOrder(planId, idempotencyKey)
    // Production uses HMS IAP (server-authoritative). Dev/previewer falls back
    // to mock — flip `useHmsIap` to true on a device with HMS Core + AGC config.
    const provider: PaymentProvider = store.useHmsIap && store.context !== null
      ? new HMSIapProvider(store.context)
      : new MockPaymentProvider()
    const result = await provider.purchase(order.storeProductId)
    const verified = await apiClient.verifyPurchase(order.orderId, result.receipt)
    store.purchaseOrder = verified
    store.purchaseStatus =
      verified.status === OrderStatus.Success ? PurchaseStatus.Success : PurchaseStatus.Failed
    if (verified.status === OrderStatus.Success) {
      // Best-effort membership refresh: re-bootstrap so the user tier reflects
      // the purchase. `initialize` needs the UIAbilityContext captured at boot.
      const context = store.context
      try {
        if (context !== null) { await store.initialize(context) }
      } catch (e) { /* best-effort membership refresh */ }
    }
    return verified.status === OrderStatus.Success
  } catch (error) {
    if (error instanceof ApiFailure && error.status === 401) {
      store.purchaseStatus = PurchaseStatus.Unauthorized
    } else if (error instanceof ApiFailure) {
      // server returned an error envelope (non-2xx)
      store.purchaseStatus = PurchaseStatus.Error
      store.purchaseMessage = error.message
    } else {
      // non-ApiFailure = transport/network failure (timeout/DNS) → offline
      store.purchaseStatus = PurchaseStatus.Offline
    }
    return false
  }
}

export function startCheckoutAction(store: AppStore, planId: string): void {
  store.purchaseStatus = PurchaseStatus.Idle
  store.pendingPlanId = planId
}
