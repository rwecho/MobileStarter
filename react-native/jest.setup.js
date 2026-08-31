// 组件测试的模块加载期前置：apiClient 在 import 时校验 EXPO_PUBLIC_APP_ID
// （与 vitest.config.ts 注入 .env 的原因相同），jest 进程同样需要显式注入。
process.env.EXPO_PUBLIC_APP_ID = process.env.EXPO_PUBLIC_APP_ID || 'test-app';
process.env.EXPO_PUBLIC_APP_ENVIRONMENT =
  process.env.EXPO_PUBLIC_APP_ENVIRONMENT || 'staging';

// 原生模块 mock：PreferencesProvider → storage → AsyncStorage。
jest.mock('@react-native-async-storage/async-storage', () =>
  require('@react-native-async-storage/async-storage/jest/async-storage-mock'),
);

// telemetry 会启动 flush 定时器吊住 jest 进程；组件测试不校验埋点，整体替身。
jest.mock('./src/telemetry/Telemetry', () => ({
  telemetry: { track: jest.fn(), screen: jest.fn(), report: jest.fn() },
}));
