/**
 * UI 组件测试（@testing-library/react-native）。
 * 与 vitest 分工：vitest 跑 node 层（data/payment，*.test.ts），
 * jest-expo 跑 React 组件（*.test.tsx）——RNTL 不支持 vitest 运行环境。
 * 运行：npm run test:component
 */
module.exports = {
  preset: 'jest-expo',
  testMatch: ['**/__tests__/**/*.test.tsx'],
  setupFiles: ['./jest.setup.js'],
};
