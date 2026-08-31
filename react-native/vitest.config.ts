import { defineConfig } from 'vitest/config';
import { loadEnv } from 'vite';

// expo 在打包时自动加载 .env，vitest 不会。apiClient 在模块加载期就校验
// EXPO_PUBLIC_APP_ID，因此把 .env 全量注入测试进程（无前缀过滤）。
export default defineConfig(({ mode }) => ({
  test: {
    environment: 'node',
    include: ['src/**/*.test.ts'],
    env: loadEnv(mode ?? 'test', process.cwd(), ''),
  },
}));
