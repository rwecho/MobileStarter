import { getDashboardMetrics } from '@/server/dashboard';
import { ConfigConsole } from './ConfigConsole';

export const dynamic = 'force-dynamic';

export default function DashboardPage() {
  const metrics = getDashboardMetrics();
  return (
    <main>
      <section className="hero">
        <p>MobileStarter Control Plane</p>
        <h1>运行时产品控制面</h1>
        <p>配置、会员、订单和通知均由服务端真实数据驱动。</p>
      </section>
      <section className="panel">
        <h2>本地环境状态</h2>
        <div className="grid">
          {metrics.map((metric) => (
            <article className="metric" key={metric.label}>
              <span>{metric.label}</span>
              <strong>{metric.value}</strong>
            </article>
          ))}
        </div>
        <p>客户端引导接口：<code>/api/v1/bootstrap</code></p>
      </section>
      <ConfigConsole />
    </main>
  );
}
