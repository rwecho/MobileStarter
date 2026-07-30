'use client';

import * as React from 'react';
import { Building2 } from 'lucide-react';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { adminFetch } from '@/lib/admin-fetch';
import { useTenant, ENVIRONMENTS } from './tenant-context';

type AppSummary = Readonly<{ appId: string; environments: readonly string[] }>;

export function TenantSwitcher() {
  const { appId, environment, setScope } = useTenant();
  const [apps, setApps] = React.useState<readonly AppSummary[]>([]);

  React.useEffect(() => {
    adminFetch<{ apps: readonly AppSummary[] }>('/api/v1/admin/apps', { appId, environment })
      .then((data) => setApps(data.apps))
      .catch(() => setApps([{ appId, environments: ENVIRONMENTS }]));
  }, [appId, environment]);

  const appOptions = apps.length
    ? apps
    : [{ appId, environments: ENVIRONMENTS as readonly string[] }];

  return (
    <div className="flex flex-wrap items-center gap-2">
      <Building2 className="text-muted-foreground size-4" aria-hidden />
      <Select value={appId} onValueChange={(value) => setScope({ appId: value })}>
        <SelectTrigger size="sm" className="w-44" aria-label="选择应用">
          <SelectValue placeholder="应用" />
        </SelectTrigger>
        <SelectContent>
          {appOptions.map((app) => (
            <SelectItem key={app.appId} value={app.appId}>
              {app.appId}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
      <span className="text-muted-foreground" aria-hidden>·</span>
      <Select value={environment} onValueChange={(value) => setScope({ environment: value })}>
        <SelectTrigger size="sm" className="w-36 capitalize" aria-label="选择环境">
          <SelectValue placeholder="环境" />
        </SelectTrigger>
        <SelectContent>
          {ENVIRONMENTS.map((env) => (
            <SelectItem key={env} value={env} className="capitalize">
              {env}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  );
}
