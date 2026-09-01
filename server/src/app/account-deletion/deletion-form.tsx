'use client';

import * as React from 'react';
import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
import { Button } from '@/components/ui/button';
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';

const DEFAULT_APP_ID = 'dshcompanion';
const APP_LABELS: Readonly<Record<string, string>> = {
  dshcompanion: '掌鲸 DSH Pocket',
};

type Step = 'auth' | 'confirm' | 'done';

interface ApiErrorBody {
  error?: { code?: string; message?: string };
}

/**
 * 账号删除自助页：不重新安装应用即可请求删除账号及相关数据
 * （Google Play「账号删除」政策要求的网页通道）。
 * 仅调用既有公开 API（sign-in + me/deletion），不含任何服务端逻辑。
 */
export function DeletionForm() {
  const params = useSearchParams();
  const appId = params.get('app')?.trim() || DEFAULT_APP_ID;
  const appLabel = APP_LABELS[appId] ?? appId;

  const [step, setStep] = React.useState<Step>('auth');
  const [identifier, setIdentifier] = React.useState('');
  const [password, setPassword] = React.useState('');
  const [confirmation, setConfirmation] = React.useState('');
  const [token, setToken] = React.useState('');
  const [busy, setBusy] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);

  const headers = React.useMemo(
    () => ({
      'content-type': 'application/json',
      'x-app-id': appId,
      'x-app-environment': 'production',
    }),
    [appId],
  );

  const errorMessage = (body: ApiErrorBody, fallback: string) =>
    body.error?.message ?? fallback;

  const signIn = async (event: React.FormEvent) => {
    event.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const response = await fetch('/api/v1/auth/sign-in', {
        method: 'POST',
        headers,
        body: JSON.stringify({
          identifier,
          password,
          deviceName: 'Account deletion portal',
        }),
      });
      const body = await response.json();
      if (!response.ok || body.error) {
        throw new Error(errorMessage(body, '登录失败，请检查账号与密码'));
      }
      setToken(body.data?.token ?? '');
      setStep('confirm');
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : '登录失败');
    } finally {
      setBusy(false);
    }
  };

  const deleteAccount = async (event: React.FormEvent) => {
    event.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const response = await fetch('/api/v1/me/deletion', {
        method: 'DELETE',
        headers: { ...headers, authorization: `Bearer ${token}` },
        body: JSON.stringify({ password, confirmation: confirmation.trim() }),
      });
      const body = await response.json();
      if (!response.ok || body.error) {
        throw new Error(errorMessage(body, '删除失败，请重试'));
      }
      setStep('done');
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : '删除失败');
    } finally {
      setBusy(false);
    }
  };

  if (step === 'done') {
    return (
      <Card className="w-full max-w-lg">
        <CardHeader>
          <CardTitle>删除请求已完成</CardTitle>
          <CardDescription>
            {appLabel} 账号及其关联个人数据已删除。
          </CardDescription>
        </CardHeader>
        <CardContent className="text-sm leading-6 text-muted-foreground">
          <p>· 通过第三方应用商店购买的订阅不会自动取消，请在对应商店的订阅设置中自行取消；</p>
          <p>· 依法必须保留的交易或安全记录将与账号分离保存，期满后删除。</p>
        </CardContent>
        <CardFooter>
          <Link href="/" className="text-sm text-primary underline-offset-4 hover:underline">
            返回首页
          </Link>
        </CardFooter>
      </Card>
    );
  }

  if (step === 'confirm') {
    return (
      <Card className="w-full max-w-lg">
        <CardHeader>
          <CardTitle>确认删除 {appLabel} 账号</CardTitle>
          <CardDescription>此操作不可撤销，请仔细阅读后再确认。</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="rounded-md border p-3 text-sm leading-6 text-muted-foreground">
            <p className="font-medium text-foreground">将被删除：</p>
            <p>账号本身、客服工单与消息、产品反馈、密码重置记录、出站消息记录；</p>
            <p>已配对的设备与电脑端授权将一并失效；遥测数据将匿名化（无法关联到你）。</p>
            <p className="mt-2 font-medium text-foreground">不受影响 / 需另行处理：</p>
            <p>第三方商店订阅不会自动取消，请在商店订阅设置中取消；依法必须保留的记录将去标识化保存至法定期限届满。</p>
          </div>
          <form id="delete-form" onSubmit={deleteAccount} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="confirmation">
                输入 <span className="font-mono font-semibold">DELETE</span> 以确认
              </Label>
              <Input
                id="confirmation"
                value={confirmation}
                onChange={(event) => setConfirmation(event.target.value)}
                placeholder="DELETE"
                autoComplete="off"
                required
              />
            </div>
            {error ? <p className="text-sm text-destructive">{error}</p> : null}
          </form>
        </CardContent>
        <CardFooter className="flex gap-2">
          <Button type="submit" form="delete-form" variant="destructive" disabled={busy || confirmation.trim() !== 'DELETE'}>
            {busy ? '处理中…' : '永久删除账号'}
          </Button>
          <Button variant="outline" disabled={busy} onClick={() => setStep('auth')}>
            取消
          </Button>
        </CardFooter>
      </Card>
    );
  }

  return (
    <Card className="w-full max-w-lg">
      <CardHeader>
        <CardTitle>删除 {appLabel} 账号</CardTitle>
        <CardDescription>
          无需重新安装应用，在此即可请求删除账号及相关数据。
        </CardDescription>
      </CardHeader>
      <form onSubmit={signIn}>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="identifier">用户名 / 邮箱 / 手机号</Label>
            <Input
              id="identifier"
              value={identifier}
              onChange={(event) => setIdentifier(event.target.value)}
              autoComplete="username"
              required
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="password">密码</Label>
            <Input
              id="password"
              type="password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              autoComplete="current-password"
              required
            />
          </div>
          {error ? <p className="text-sm text-destructive">{error}</p> : null}
        </CardContent>
        <CardFooter className="flex flex-col items-stretch gap-3">
          <Button type="submit" disabled={busy}>
            {busy ? '登录中…' : '登录并继续'}
          </Button>
          <p className="text-xs leading-5 text-muted-foreground">
            删除前你可以查看
            {' '}
            <Link href="/legal/privacy" className="underline underline-offset-4">
              隐私政策
            </Link>
            。删除操作需要密码二次验证，且不可撤销。
          </p>
        </CardFooter>
      </form>
    </Card>
  );
}
