import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'MobileStarter Control Plane',
  description: 'Dynamic mobile application control plane',
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
