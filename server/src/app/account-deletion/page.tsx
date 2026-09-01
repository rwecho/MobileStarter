import type { Metadata } from 'next';
import { Suspense } from 'react';
import { DeletionForm } from './deletion-form';

export const metadata: Metadata = {
  title: '删除账号 | Zhongbei Auth',
  description: '请求删除账号及相关数据（无需重新安装应用）。',
};

export default function AccountDeletionPage() {
  return (
    <Suspense fallback={null}>
      <DeletionForm />
    </Suspense>
  );
}
