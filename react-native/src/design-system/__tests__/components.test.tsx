import React from 'react';
import { fireEvent } from '@testing-library/react-native';
import { renderWithProviders } from '../../test/testUtils';
import { AppButton } from '../components';

// PreferencesProvider 内部消费 useApp，组件测试统一给最小替身
// （避免拖起 AppProvider 的整棵启动树）。
jest.mock('../../state/AppStore', () => ({
  useApp: () => ({
    online: true,
    back: jest.fn(),
    canGoBack: false,
    navigate: jest.fn(),
    refreshBootstrap: jest.fn(),
  }),
}));

// AppButton 是无外部依赖的纯展示组件（palette 来自 PreferencesProvider，
// AsyncStorage 已在 jest.setup.js mock），适合作为组件测试的最小样例。
describe('AppButton', () => {
  it('渲染 label 并在点击时触发 onPress', () => {
    const onPress = jest.fn();
    const screen = renderWithProviders(<AppButton label="确认下单" onPress={onPress} />);
    expect(screen.getByText('确认下单')).toBeTruthy();
    fireEvent.press(screen.getByText('确认下单'));
    expect(onPress).toHaveBeenCalledTimes(1);
  });

  it('disabled 时不触发 onPress', () => {
    const onPress = jest.fn();
    const screen = renderWithProviders(<AppButton label="删除账号" onPress={onPress} disabled />);
    fireEvent.press(screen.getByText('删除账号'));
    expect(onPress).not.toHaveBeenCalled();
  });
});
