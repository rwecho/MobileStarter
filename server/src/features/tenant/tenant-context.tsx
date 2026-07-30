'use client';

import * as React from 'react';

export type TenantScope = Readonly<{
  appId: string;
  environment: string;
}>;

export const ENVIRONMENTS = ['development', 'staging', 'production'] as const;
export type Environment = (typeof ENVIRONMENTS)[number];

const STORAGE_KEY = 'mobileui.console.tenant';
const DEFAULT_SCOPE: TenantScope = {
  appId: 'mobileui',
  environment: 'development',
};

type TenantContextValue = TenantScope & {
  ready: boolean;
  setScope: (patch: Partial<TenantScope>) => void;
};

const TenantContext = React.createContext<TenantContextValue | null>(null);

export function TenantProvider({ children }: Readonly<{ children: React.ReactNode }>) {
  const [scope, setScopeState] = React.useState<TenantScope>(DEFAULT_SCOPE);
  const [ready, setReady] = React.useState(false);

  React.useEffect(() => {
    try {
      const raw = window.localStorage.getItem(STORAGE_KEY);
      // eslint-disable-next-line react-hooks/set-state-in-effect -- hydrate tenant from external localStorage
      if (raw) setScopeState({ ...DEFAULT_SCOPE, ...JSON.parse(raw) as Partial<TenantScope> });
    } catch {
      /* ignore malformed storage */
    }
    setReady(true);
  }, []);

  const setScope = React.useCallback((patch: Partial<TenantScope>) => {
    setScopeState((prev) => {
      const next = { ...prev, ...patch };
      try {
        window.localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
      } catch {
        /* storage unavailable, keep in-memory */
      }
      return next;
    });
  }, []);

  const value = React.useMemo<TenantContextValue>(
    () => ({ ...scope, ready, setScope }),
    [scope, ready, setScope],
  );

  return <TenantContext.Provider value={value}>{children}</TenantContext.Provider>;
}

export function useTenant(): TenantContextValue {
  const ctx = React.useContext(TenantContext);
  if (!ctx) throw new Error('useTenant must be used within a TenantProvider');
  return ctx;
}
