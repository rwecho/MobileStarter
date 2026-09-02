import type { Metadata } from 'next';
import { headers } from 'next/headers';
import Link from 'next/link';
import { getRuntimeConfig } from '@/server/database';
import { DEFAULT_APP_ID } from '@/server/service-identity';
import { readPublicParam, resolvePublicLocale, type PublicLocale } from '@/server/public-locale';

export const dynamic = 'force-dynamic';

type Props = {
  searchParams: Promise<Readonly<Record<string, string | readonly string[]>>>;
};

const LABELS = {
  'zh-CN': {
    features: '核心特性',
    tiers: '会员方案',
    appStore: 'App Store 下载',
    googlePlay: 'Google Play 下载',
    comingSoon: '即将上线',
    support: '支持与帮助',
    privacy: '隐私政策',
    terms: '用户协议',
    deletion: '删除账号',
  },
  'en-US': {
    features: 'Key Features',
    tiers: 'Membership',
    appStore: 'Download on the App Store',
    googlePlay: 'Get it on Google Play',
    comingSoon: 'Coming Soon',
    support: 'Support & Help',
    privacy: 'Privacy Policy',
    terms: 'Terms of Service',
    deletion: 'Delete Account',
  },
} as const satisfies Readonly<Record<PublicLocale, Readonly<Record<string, string>>>>;

async function resolveScope(searchParams: Props['searchParams']) {
  const sp = await searchParams;
  const acceptLanguage = (await headers()).get('accept-language');
  return {
    appId: readPublicParam(sp.app) ?? DEFAULT_APP_ID,
    locale: resolvePublicLocale(sp.locale, acceptLanguage),
  };
}

export async function generateMetadata({ searchParams }: Props): Promise<Metadata> {
  const { appId } = await resolveScope(searchParams);
  const config = await getRuntimeConfig(appId, 'production');
  return { title: `${config.brand.appName} — ${config.brand.tagline}` };
}

export default async function MarketingPage({ searchParams }: Props) {
  const { appId, locale } = await resolveScope(searchParams);
  const config = await getRuntimeConfig(appId, 'production');
  const label = LABELS[locale];
  const { brand, webPresence } = config;

  const appParam = `app=${encodeURIComponent(appId)}`;
  const legalHref = (type: string) => `/legal/${type}?${appParam}&locale=${locale}`;
  const entitlementLabel = new Map(config.entitlements.map((item) => [item.key, item.label]));

  return (
    <main className="bg-background text-foreground min-h-svh">
      {/* Hero：品牌名 + 标语，主题色仅做点缀（正式商店页截图为主视觉） */}
      <section
        className="border-b"
        style={{ background: `linear-gradient(180deg, ${brand.primaryColor}1f, transparent)` }}
      >
        <div className="mx-auto max-w-4xl px-6 py-16">
          <h1 className="text-4xl font-semibold tracking-tight">{brand.appName}</h1>
          <p className="text-muted-foreground mt-3 max-w-xl text-lg leading-relaxed">{brand.tagline}</p>
          <div className="mt-6 flex flex-wrap items-center gap-3">
            {webPresence.appStoreUrl ? (
              <a
                className="rounded-md px-5 py-2.5 text-sm font-medium text-white"
                style={{ backgroundColor: brand.primaryColor }}
                href={webPresence.appStoreUrl}
                target="_blank"
                rel="noreferrer"
              >
                {label.appStore}
              </a>
            ) : null}
            {webPresence.googlePlayUrl ? (
              <a
                className="rounded-md border px-5 py-2.5 text-sm font-medium"
                href={webPresence.googlePlayUrl}
                target="_blank"
                rel="noreferrer"
              >
                {label.googlePlay}
              </a>
            ) : null}
            {!webPresence.appStoreUrl && !webPresence.googlePlayUrl ? (
              <span className="text-muted-foreground text-sm">{label.comingSoon}</span>
            ) : null}
          </div>
        </div>
      </section>

      <div className="mx-auto max-w-4xl px-6 py-12">
        {/* 特性：权益即卖点，直接复用会员权益文案 */}
        <section>
          <h2 className="text-xl font-semibold tracking-tight">{label.features}</h2>
          <div className="mt-4 grid gap-4 sm:grid-cols-2">
            {config.entitlements.map((item) => (
              <div key={item.key} className="rounded-lg border p-4">
                <p className="text-sm font-medium">{item.label}</p>
                <p className="text-muted-foreground mt-1 text-sm leading-relaxed">{item.description}</p>
              </div>
            ))}
          </div>
        </section>

        {/* 会员：等级卡片，不标价（价格与区间随上架区域变化，以应用内为准） */}
        <section className="mt-12">
          <h2 className="text-xl font-semibold tracking-tight">{label.tiers}</h2>
          <div className="mt-4 grid gap-4 sm:grid-cols-3">
            {config.tiers.map((tier) => (
              <div
                key={tier.id}
                className="rounded-lg border p-5"
                style={tier.recommended ? { borderColor: tier.accent } : undefined}
              >
                <p className="text-sm font-semibold">{tier.name}</p>
                <p className="text-muted-foreground mt-1 text-sm">{tier.summary}</p>
                <ul className="mt-3 grid gap-1.5">
                  {tier.entitlements.map((key) => (
                    <li key={key} className="text-muted-foreground text-xs">· {entitlementLabel.get(key) ?? key}</li>
                  ))}
                </ul>
              </div>
            ))}
          </div>
        </section>

        {/* 页脚：法务与支持链接（App Store 审核会顺藤摸瓜核对） */}
        <footer className="mt-12 border-t pt-6">
          <ul className="flex flex-wrap gap-x-5 gap-y-2 text-sm">
            <li><Link className="text-info underline underline-offset-4" href={`/support?${appParam}&locale=${locale}`}>{label.support}</Link></li>
            <li><Link className="text-info underline underline-offset-4" href={legalHref('privacy')}>{label.privacy}</Link></li>
            <li><Link className="text-info underline underline-offset-4" href={legalHref('terms')}>{label.terms}</Link></li>
            <li><Link className="text-info underline underline-offset-4" href={`/account-deletion?${appParam}`}>{label.deletion}</Link></li>
          </ul>
          <p className="text-muted-foreground mt-3 text-xs">
            <a href={`mailto:${webPresence.contactEmail}`}>{webPresence.contactEmail}</a>
          </p>
        </footer>
      </div>
    </main>
  );
}
