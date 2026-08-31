import { useCallback, useMemo, useState } from 'react';
import Toast from 'react-native-toast-message';

type ToastTone = 'success' | 'info' | 'error';
export type ConfirmState = Readonly<{
  title: string;
  message: string;
  confirmLabel: string;
  onConfirm: () => void | Promise<void>;
}>;

export function useFeedbackState() {
  const [confirm, setConfirm] = useState<ConfirmState | null>(null);
  const showToast = useCallback((message: string, tone: ToastTone = 'info') => {
    // 展示与动画交给 react-native-toast-message（顶部、全局唯一挂载于 FeedbackHost）。
    Toast.show({ type: tone, text1: message, position: 'top', visibilityTime: 2400 });
  }, []);
  return useMemo(() => ({
    confirm,
    showToast,
    showConfirm: setConfirm,
    closeConfirm: () => setConfirm(null),
  }), [confirm, showToast]);
}
