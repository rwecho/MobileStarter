import React, { ReactElement } from 'react';
import { render, RenderOptions } from '@testing-library/react-native';
import { PreferencesProvider } from '../preferences/PreferencesProvider';

// 组件测试的统一挂载点：design-system 组件消费 usePreferences，
// 全局 store（useApp）由各测试自行 jest.mock 提供最小上下文。
export function renderWithProviders(
  ui: ReactElement,
  options?: Omit<RenderOptions, 'wrapper'>,
) {
  return render(ui, {
    wrapper: ({ children }) => (
      <PreferencesProvider>{children}</PreferencesProvider>
    ),
    ...options,
  });
}
