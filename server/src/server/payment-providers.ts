import { RuntimeConfig } from '@/domain/config';
import { ApiError } from './http';

type BillingPlan = RuntimeConfig['plans'][number];
type StartPaymentInput = Readonly<{
  appId: string;
  environment: string;
  userId: string;
  plan: BillingPlan;
}>;

export type PaymentStart = Readonly<{
  complete: boolean;
}>;

export interface PaymentProviderPort {
  readonly id: BillingPlan['provider'];
  start(input: StartPaymentInput): Promise<PaymentStart>;
}

const mockProvider: PaymentProviderPort = {
  id: 'mock',
  async start() {
    return { complete: true };
  },
};

const unavailableProviders = new Map<string, PaymentProviderPort>(
  (['apple', 'google', 'wechat', 'alipay'] as const).map((id) => [id, {
    id,
    async start() {
      throw new ApiError(
        503,
        'PAYMENT_PROVIDER_NOT_CONFIGURED',
        `${id} 支付尚未配置`,
        true,
      );
    },
  }]),
);

export function paymentProvider(id: BillingPlan['provider']) {
  if (id === 'mock') return mockProvider;
  const provider = unavailableProviders.get(id);
  if (!provider) {
    throw new ApiError(400, 'PAYMENT_PROVIDER_UNSUPPORTED', '不支持的支付渠道');
  }
  return provider;
}
