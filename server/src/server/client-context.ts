import { NextRequest } from 'next/server';

export type ClientPlatform = 'ios' | 'android' | 'harmonyos' | 'web';

export function getClientContext(request: NextRequest) {
  const platformHeader = request.headers.get('x-platform');
  const platform: ClientPlatform = isPlatform(platformHeader) ? platformHeader : 'web';
  return {
    appId: request.headers.get('x-app-id')?.trim() || 'mobileui',
    environment: request.headers.get('x-app-environment')?.trim() || 'development',
    platform,
    appVersion: request.headers.get('x-app-version')?.trim() || '0.0.0',
    locale: request.headers.get('accept-language')?.split(',')[0] || 'zh-CN',
  };
}

function isPlatform(value: string | null): value is ClientPlatform {
  return value === 'ios' || value === 'android' || value === 'harmonyos' || value === 'web';
}

