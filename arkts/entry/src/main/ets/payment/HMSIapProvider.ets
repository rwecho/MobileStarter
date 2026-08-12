/**
 * HMS IAP provider — server-authoritative, mirrors the Flutter/RN IapPaymentProvider.
 *
 * Uses HarmonyOS IAP Kit (@kit.IAPKit). The client sends `purchaseToken`
 * → server HMSAdapter calls HMS IAP server verification API → authoritative verify.
 *
 * On HarmonyOS every device has HMS Core, so this is the production provider.
 * Use MockPaymentProvider for dev/testing.
 *
 * API notes (IAPKit @hms.core.iap, API 18):
 *  - queryProducts(context, productIds: string[]): Promise<Array<Product>>
 *  - purchase(context, { productId, productType, ... }): Promise<PurchaseResult>
 *  - queryOwnedPurchases(context, { productType }): Promise<QueryPurchasesResult>
 *  - PurchaseResult.inAppPurchaseData is a JSON string carrying purchaseToken.
 */
import common from '@ohos.app.ability.common'
import { iap } from '@kit.IAPKit'
import { PurchaseResult, StoreProduct, StoreProductMapping } from '../domain/Models'
import { PaymentProvider } from './PaymentProvider'

export class HMSIapProvider implements PaymentProvider {
  private context: common.UIAbilityContext
  // Subscriptions are auto-renewable on this app; overridable if a plan maps a
  // consumable / non-consumable product.
  private productType: iap.ProductType = iap.ProductType.AUTORENEWABLE

  constructor(context: common.UIAbilityContext) {
    this.context = context
  }

  loadProducts(mapping: StoreProductMapping | null): Promise<StoreProduct[]> {
    if (mapping == null || mapping.hms == null || mapping.hms.length === 0) {
      return Promise.resolve([])
    }
    return iap.queryProducts(this.context, [mapping.hms])
      .then((products: iap.Product[]) => {
        const result: StoreProduct[] = []
        for (const p of products) {
          result.push({ storeProductId: p.id })
        }
        return result
      })
  }

  purchase(storeProductId: string): Promise<PurchaseResult> {
    return iap.purchase(this.context, {
      productId: storeProductId,
      productType: this.productType
    })
      .then((result: iap.PurchaseResult): PurchaseResult => {
        // HMS receipt for the server adapter is the purchaseToken string
        // (hms-adapter.ts asserts typeof receipt === 'string').
        const purchaseToken = this.extractPurchaseToken(result.inAppPurchaseData)
        return { storeProductId, receipt: purchaseToken }
      })
  }

  restore(): Promise<PurchaseResult[]> {
    return iap.queryOwnedPurchases(this.context, {
      productType: this.productType
    })
      .then((owned: iap.QueryPurchasesResult) => {
        const results: PurchaseResult[] = []
        const productList = owned.productList ?? []
        const dataList = owned.inAppPurchaseDataList ?? []
        for (let i = 0; i < productList.length; i++) {
          const token = this.extractPurchaseToken(dataList[i] ?? '')
          results.push({ storeProductId: productList[i], receipt: token })
        }
        return results
      })
  }

  private extractPurchaseToken(inAppPurchaseData: string): string {
    try {
      const data = JSON.parse(inAppPurchaseData) as Record<string, string>
      return data['purchaseToken'] ?? ''
    } catch {
      // Fall back to the raw payload — some SDK versions return the token directly.
      return inAppPurchaseData
    }
  }
}
