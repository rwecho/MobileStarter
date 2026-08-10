import { PurchaseResult, StoreProduct, StoreProductMapping } from '../domain/Models'
import { PaymentProvider } from './PaymentProvider'

export class MockPaymentProvider implements PaymentProvider {
  failPurchases: boolean = false
  private owned: string[] = []

  loadProducts(mapping: StoreProductMapping | null): Promise<StoreProduct[]> {
    const products: StoreProduct[] = []
    if (mapping == null) return Promise.resolve(products)
    if (mapping.apple != null) products.push({ storeProductId: mapping.apple })
    if (mapping.google != null) products.push({ storeProductId: mapping.google })
    if (mapping.hms != null) products.push({ storeProductId: mapping.hms })
    return Promise.resolve(products)
  }

  purchase(storeProductId: string): Promise<PurchaseResult> {
    const receipt: Record<string, string | boolean> = { productId: storeProductId }
    if (this.failPurchases) {
      receipt['fail'] = true
    } else {
      this.owned.push(storeProductId)
    }
    return Promise.resolve({ storeProductId, receipt })
  }

  restore(): Promise<PurchaseResult[]> {
    const results: PurchaseResult[] = []
    for (let i = 0; i < this.owned.length; i++) {
      results.push({ storeProductId: this.owned[i], receipt: { productId: this.owned[i] } })
    }
    return Promise.resolve(results)
  }
}
