import React from 'react';
import { fireEvent } from '@testing-library/react-native';
import { renderWithProviders } from '../../test/testUtils';
import { FeedbackHost } from '../FeedbackHost';

// FeedbackHost 绑定全局 AppStore；组件测试里用最小上下文替身，
// 只提供被测路径用到的 confirm 状态（避免拖起整棵 Provider 树）。
// babel-jest 提升 jest.mock：工厂里只能引用 `mock` 前缀的变量。
const mockCloseConfirm = jest.fn();
jest.mock('../../state/AppStore', () => ({
  useApp: () => ({
    confirm: {
      title: '删除账号',
      message: '此操作不可撤销，确定继续吗？',
      confirmLabel: '永久删除',
      onConfirm: () => undefined,
    },
    closeConfirm: mockCloseConfirm,
  }),
}));

describe('FeedbackHost 确认弹窗', () => {
  it('渲染标题与确认按钮，点击取消回调 closeConfirm', () => {
    const screen = renderWithProviders(<FeedbackHost />);
    expect(screen.getByText('删除账号')).toBeTruthy();
    expect(screen.getByText('永久删除')).toBeTruthy();
    fireEvent.press(screen.getByText('取消'));
    expect(mockCloseConfirm).toHaveBeenCalledTimes(1);
  });
});
