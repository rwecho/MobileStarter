'use client';

import * as React from 'react';
import { toast } from 'sonner';
import { History, RotateCcw, Save, Send } from 'lucide-react';
import { RuntimeConfig } from '@/domain/config';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardAction, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import {
  Dialog, DialogClose, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle,
} from '@/components/ui/dialog';
import { Label } from '@/components/ui/label';
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from '@/components/ui/select';
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from '@/components/ui/table';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Textarea } from '@/components/ui/textarea';
import { adminFetch } from '@/lib/admin-fetch';
import { formatDateTime } from '@/lib/format';
import { useTenant } from '@/features/tenant/tenant-context';
import { PageHeader } from '@/features/console/page-header';

type Envelope = Readonly<{ published: RuntimeConfig; draft: RuntimeConfig | null }>;
type Revision = Readonly<{ version: number; action: string; actor: string; createdAt: string }>;
type AuditEntry = Readonly<{
  id: string; action: string; actor: string;
  fromVersion: number | null; toVersion: number; createdAt: string;
}>;

type Phase = 'idle' | 'loading' | 'busy' | 'error';

export function ConfigConsole() {
  const { appId, environment, ready } = useTenant();
  const scope = React.useMemo(() => ({ appId, environment }), [appId, environment]);

  const [doc, setDoc] = React.useState('');
  const [phase, setPhase] = React.useState<Phase>('idle');
  const [message, setMessage] = React.useState('读取当前租户的运行时配置。');
  const [hasDraft, setHasDraft] = React.useState(false);
  const [revisions, setRevisions] = React.useState<readonly Revision[]>([]);
  const [audit, setAudit] = React.useState<readonly AuditEntry[]>([]);
  const [confirm, setConfirm] = React.useState<null | 'publish'>(null);
  const [rollbackVersion, setRollbackVersion] = React.useState<string>('');

  const loadAll = React.useCallback(async () => {
    setPhase('loading');
    try {
      const [envelope, history] = await Promise.all([
        adminFetch<Envelope>('/api/v1/admin/config', scope),
        adminFetch<{ revisions: readonly Revision[]; audit: readonly AuditEntry[] }>(
          '/api/v1/admin/config/revisions',
          scope,
        ),
      ]);
      setDoc(JSON.stringify(envelope.draft ?? envelope.published, null, 2));
      setHasDraft(Boolean(envelope.draft));
      setRevisions(history.revisions);
      setAudit(history.audit);
      setMessage(envelope.draft ? '已载入未发布草稿。' : '已载入当前发布版本。');
      setPhase('idle');
    } catch (error) {
      setPhase('error');
      setMessage(errorMessage(error));
    }
  }, [scope]);

  React.useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- initial config load driven by tenant scope
    if (ready) void loadAll();
  }, [loadAll, ready]);

  const saveDraft = async () => {
    setPhase('busy');
    try {
      const parsed = JSON.parse(doc) as RuntimeConfig;
      await adminFetch('/api/v1/admin/config', scope, {
        method: 'PUT',
        body: JSON.stringify(parsed),
      });
      toast.success('草稿已保存', { description: '客户端配置尚未改变，需发布后生效。' });
      await loadAll();
    } catch (error) {
      toast.error('保存失败', { description: errorMessage(error) });
      setPhase('error');
    }
  };

  const publish = async () => {
    setPhase('busy');
    try {
      await adminFetch('/api/v1/admin/config/publish', scope, { method: 'POST' });
      toast.success('草稿已发布', { description: '客户端将在刷新策略触发后获取新版本。' });
      await loadAll();
    } catch (error) {
      toast.error('发布失败', { description: errorMessage(error) });
      setPhase('error');
    }
  };

  const rollback = async () => {
    const version = Number(rollbackVersion);
    if (!version) return;
    setPhase('busy');
    try {
      await adminFetch('/api/v1/admin/config/rollback', scope, {
        method: 'POST',
        body: JSON.stringify({ version }),
      });
      toast.success(`已恢复至版本 ${version}`, { description: '已生成新的发布版本。' });
      setRollbackVersion('');
      await loadAll();
    } catch (error) {
      toast.error('回滚失败', { description: errorMessage(error) });
      setPhase('error');
    }
  };

  const busy = phase === 'busy' || phase === 'loading';

  return (
    <div className="flex flex-col gap-6">
      <PageHeader title="多租户配置" description={`运行时配置草稿、发布与回滚 · ${appId} · ${environment}`}>
        <Badge variant={hasDraft ? 'warning' : 'secondary'}>
          {hasDraft ? '有未发布草稿' : '无草稿'}
        </Badge>
      </PageHeader>

      <Card>
        <CardHeader className="border-b">
          <CardTitle>配置文档</CardTitle>
          <CardDescription>编辑 JSON 草稿，校验通过后保存并发布到当前环境。</CardDescription>
          <CardAction>
            <Button variant="outline" size="sm" onClick={() => void loadAll()} disabled={busy}>
              读取
            </Button>
          </CardAction>
        </CardHeader>
        <CardContent className="flex flex-col gap-4 pt-6">
          <Tabs defaultValue="edit">
            <TabsList>
              <TabsTrigger value="edit">编辑</TabsTrigger>
              <TabsTrigger value="revisions">版本历史</TabsTrigger>
              <TabsTrigger value="audit">审计日志</TabsTrigger>
            </TabsList>
            <TabsContent value="edit" className="mt-4 flex flex-col gap-3">
              <Textarea
                value={doc}
                onChange={(event) => setDoc(event.target.value)}
                spellCheck={false}
                className="min-h-[420px] font-mono text-xs"
              />
              <div className="flex flex-wrap gap-2">
                <Button onClick={saveDraft} disabled={busy} className="gap-2">
                  <Save className="size-4" /> 保存草稿
                </Button>
                <Button onClick={() => setConfirm('publish')} disabled={busy || !hasDraft} className="gap-2">
                  <Send className="size-4" /> 发布
                </Button>
                <Button
                  variant="outline"
                  onClick={() => setRollbackVersion(revisions[0]?.version.toString() ?? '')}
                  disabled={busy || revisions.length === 0}
                  className="gap-2"
                >
                  <RotateCcw className="size-4" /> 回滚
                </Button>
              </div>
              <p className="text-muted-foreground text-sm" role="status">{message}</p>
            </TabsContent>
            <TabsContent value="revisions" className="mt-4">
              <RevisionTable revisions={revisions} />
            </TabsContent>
            <TabsContent value="audit" className="mt-4">
              <AuditTable audit={audit} />
            </TabsContent>
          </Tabs>
        </CardContent>
      </Card>

      <Dialog open={confirm === 'publish'} onOpenChange={(open) => !open && setConfirm(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>发布配置草稿？</DialogTitle>
            <DialogDescription>发布后客户端将在刷新策略触发后获取新版本，此操作会生成新的配置版本。</DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <DialogClose asChild><Button variant="outline">取消</Button></DialogClose>
            <DialogClose asChild>
              <Button onClick={publish}>确认发布</Button>
            </DialogClose>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <Dialog open={rollbackVersion !== ''} onOpenChange={(open) => !open && setRollbackVersion('')}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>回滚到历史版本</DialogTitle>
            <DialogDescription>选择要恢复的版本，将以其内容生成新的发布版本。</DialogDescription>
          </DialogHeader>
          <div className="grid gap-2">
            <Label htmlFor="rollback-version">目标版本</Label>
            <Select value={rollbackVersion} onValueChange={setRollbackVersion}>
              <SelectTrigger id="rollback-version" className="w-full"><SelectValue placeholder="选择版本" /></SelectTrigger>
              <SelectContent>
                {revisions.map((revision) => (
                  <SelectItem key={revision.version} value={revision.version.toString()}>
                    v{revision.version} · {revision.action} · {formatDateTime(revision.createdAt)}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
          <DialogFooter>
            <DialogClose asChild><Button variant="outline">取消</Button></DialogClose>
            <DialogClose asChild>
              <Button variant="destructive" onClick={rollback} disabled={!rollbackVersion}>
                确认回滚
              </Button>
            </DialogClose>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

function RevisionTable({ revisions }: Readonly<{ revisions: readonly Revision[] }>) {
  if (!revisions.length) return <EmptyRow text="暂无版本记录" />;
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>版本</TableHead>
          <TableHead>操作</TableHead>
          <TableHead>操作者</TableHead>
          <TableHead>时间</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {revisions.map((revision) => (
          <TableRow key={revision.version}>
            <TableCell className="font-mono">v{revision.version}</TableCell>
            <TableCell>
              <Badge variant="outline" className="gap-1"><History className="size-3" />{revision.action}</Badge>
            </TableCell>
            <TableCell>{revision.actor}</TableCell>
            <TableCell className="text-muted-foreground">{formatDateTime(revision.createdAt)}</TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  );
}

function AuditTable({ audit }: Readonly<{ audit: readonly AuditEntry[] }>) {
  if (!audit.length) return <EmptyRow text="暂无审计记录" />;
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>操作</TableHead>
          <TableHead>操作者</TableHead>
          <TableHead>版本变更</TableHead>
          <TableHead>时间</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {audit.map((entry) => (
          <TableRow key={entry.id}>
            <TableCell><Badge variant="outline">{entry.action}</Badge></TableCell>
            <TableCell>{entry.actor}</TableCell>
            <TableCell className="font-mono text-xs">
              {entry.fromVersion ?? '—'} → v{entry.toVersion}
            </TableCell>
            <TableCell className="text-muted-foreground">{formatDateTime(entry.createdAt)}</TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  );
}

function EmptyRow({ text }: Readonly<{ text: string }>) {
  return <p className="text-muted-foreground py-6 text-center text-sm">{text}</p>;
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : '操作失败';
}
