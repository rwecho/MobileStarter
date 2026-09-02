export type PublicLocale = 'zh-CN' | 'en-US';

const SUPPORTED_EXACT = new Set(['zh-CN', 'en-US']);

function fromTag(tag: string): PublicLocale | null {
  const base = tag.trim().toLowerCase().split('-')[0];
  if (base === 'zh') return 'zh-CN';
  if (base === 'en') return 'en-US';
  return null;
}

/**
 * 公开网页语言解析：显式 ?locale= 优先，其次 Accept-Language 协商。
 * 兜底英文——App Store 的 Support/Marketing URL 全球唯一，美区审核员
 * 会带着 en-US 的 Accept-Language 直接打开，页面必须可读。
 */
export function resolvePublicLocale(
  param: string | readonly string[] | undefined,
  acceptLanguage: string | null,
): PublicLocale {
  if (typeof param === 'string' && SUPPORTED_EXACT.has(param.trim())) {
    return param.trim() as PublicLocale;
  }
  if (typeof param === 'string' && param.trim()) {
    const byBase = fromTag(param);
    if (byBase) return byBase;
  }
  if (acceptLanguage) {
    for (const part of acceptLanguage.split(',')) {
      const tag = part.split(';')[0] ?? '';
      const byTag = fromTag(tag);
      if (byTag) return byTag;
    }
  }
  return 'en-US';
}

/** 从 searchParams 读单值字符串（与公开 legal 页同一约定）。 */
export function readPublicParam(
  value: string | readonly string[] | undefined,
): string | undefined {
  return typeof value === 'string' && value.trim() ? value.trim() : undefined;
}
