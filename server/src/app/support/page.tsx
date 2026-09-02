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
    heading: '支持与帮助',
    intro: '在使用中遇到问题？先查看常见问题，仍未解决请直接邮件联系我们。',
    contactTitle: '联系我们',
    contactHint: '我们会在 1-2 个工作日内回复。',
    faqTitle: '常见问题',
    linksTitle: '相关链接',
    privacy: '隐私政策',
    terms: '用户协议',
    subscription: '订阅说明',
    deletion: '删除账号',
    download: '前往 App Store 下载',
  },
  'en-US': {
    heading: 'Support & Help',
    intro: 'Having trouble? Check the FAQ below, or email us directly and we will help you out.',
    contactTitle: 'Contact Us',
    contactHint: 'We usually reply within 1-2 business days.',
    faqTitle: 'Frequently Asked Questions',
    linksTitle: 'Related Links',
    privacy: 'Privacy Policy',
    terms: 'Terms of Service',
    subscription: 'Subscription Details',
    deletion: 'Delete Account',
    download: 'Download on the App Store',
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
  const { appId, locale } = await resolveScope(searchParams);
  const config = await getRuntimeConfig(appId, 'production');
  const label = LABELS[locale];
  return { title: `${label.heading} | ${config.brand.appName}` };
}

export default async function SupportPage({ searchParams }: Props) {
  const { appId, locale } = await resolveScope(searchParams);
  const config = await getRuntimeConfig(appId, 'production');
  const label = LABELS[locale];

  // FAQ 先取请求语言的文档，缺语言时回退全部（与公开 legal 页同一降级策略）
  const faq = config.support.help.filter((item) => item.locale === locale);
  const faqItems = faq.length > 0
    ? faq
    : config.support.help;

  const appParam = `app=${encodeURIComponent(appId)}`;
  const legalHref = (type: string) => `/legal/${type}?${appParam}&locale=${locale}`;

  return (
    <main className="bg-background text-foreground min-h-svh">
      <article className="mx-auto max-w-3xl px-6 py-12">
        <p className="text-muted-foreground text-xs tracking-widest uppercase">
          {config.brand.appName} · {appId}
        </p>
        <h1 className="mt-2 text-2xl font-semibold tracking-tight">{label.heading}</h1>
        <p className="text-muted-foreground mt-2 text-sm">{label.intro}</p>

        <section className="mt-8 rounded-lg border bg-surface p-5">
          <h2 className="text-base font-semibold">{label.contactTitle}</h2>
          <p className="mt-1 text-sm">
            <a className="text-info underline underline-offset-4" href={`mailto:${config.webPresence.contactEmail}`}>
              {config.webPresence.contactEmail}
            </a>
          </p>
          <p className="text-muted-foreground mt-1 text-xs">{label.contactHint}</p>
        </section>

        <section className="mt-8">
          <h2 className="text-base font-semibold">{label.faqTitle}</h2>
          <div className="mt-3 grid gap-3">
            {faqItems.map((item) => (
              <details key={item.id} className="rounded-lg border p-4">
                <summary className="cursor-pointer text-sm font-medium">{item.title}</summary>
                <p className="text-muted-foreground mt-2 text-sm leading-relaxed whitespace-pre-line">{item.body}</p>
              </details>
            ))}
          </div>
        </section>

        <section className="mt-8">
          <h2 className="text-base font-semibold">{label.linksTitle}</h2>
          <ul className="mt-3 grid gap-2 text-sm">
            <li><Link className="text-info underline underline-offset-4" href={legalHref('privacy')}>{label.privacy}</Link></li>
            <li><Link className="text-info underline underline-offset-4" href={legalHref('terms')}>{label.terms}</Link></li>
            <li><Link className="text-info underline underline-offset-4" href={legalHref('subscription')}>{label.subscription}</Link></li>
            <li><Link className="text-info underline underline-offset-4" href={`/account-deletion?${appParam}`}>{label.deletion}</Link></li>
            {config.webPresence.appStoreUrl ? (
              <li>
                <a className="text-info underline underline-offset-4" href={config.webPresence.appStoreUrl} target="_blank" rel="noreferrer">
                  {label.download}
                </a>
              </li>
            ) : null}
          </ul>
        </section>
      </article>
    </main>
  );
}
