import React from 'react';
import { Modal, Pressable, StyleSheet, Text, View } from 'react-native';
import Toast, { ToastConfig } from 'react-native-toast-message';
import { useApp } from '../state/AppStore';
import { usePreferences } from '../preferences/PreferencesProvider';
import { colors, radii, spacing, ThemeColors } from '../theme/tokens';
import { styles } from '../theme/styles';
import { AppIcon } from './AppIcon';
import { AppButton } from './components';

// react-native-toast-message 的自定义卡片：沿用设计系统 token（表面色 + 描边 + 语义图标），
// 由 FeedbackHost 全局唯一挂载，位置统一为顶部（与 ArkTS/Flutter 端一致）。
function toastConfigFor(palette: ThemeColors): ToastConfig {
  const card = (text: string, icon: 'alert' | 'check', tone: string) => (
    <View style={[toastStyles.card, { backgroundColor: palette.surface, borderColor: palette.border }]}>
      <AppIcon name={icon} color={tone} size={20} />
      <Text style={styles.body}>{text}</Text>
    </View>
  );
  return {
    success: ({ text1 }) => card(text1 ?? '', 'check', colors.success),
    info: ({ text1 }) => card(text1 ?? '', 'check', colors.info),
    error: ({ text1 }) => card(text1 ?? '', 'alert', colors.error),
  };
}

export function FeedbackHost() {
  const { confirm, closeConfirm } = useApp();
  const { palette } = usePreferences();
  return (
    <>
      <Toast config={toastConfigFor(palette)} topOffset={spacing.x3} />
      <Modal visible={Boolean(confirm)} transparent animationType="fade">
        <Pressable style={feedbackStyles.scrim} onPress={closeConfirm}>
          <Pressable
            style={[feedbackStyles.dialog, { backgroundColor: palette.surface }]}
            onPress={() => undefined}
          >
            <View style={[feedbackStyles.alertIcon, { backgroundColor: palette.brandSoft }]}>
              <AppIcon name="alert" color={colors.warning} size={28} />
            </View>
            <Text style={styles.heading}>{confirm?.title}</Text>
            <Text style={[styles.secondary, feedbackStyles.center]}>{confirm?.message}</Text>
            <View style={feedbackStyles.actions}>
              <View style={feedbackStyles.action}>
                <AppButton label="取消" variant="secondary" onPress={closeConfirm} />
              </View>
              <View style={feedbackStyles.action}>
                <AppButton
                  label={confirm?.confirmLabel ?? '确认'}
                  variant="danger"
                  onPress={() => {
                    confirm?.onConfirm();
                    closeConfirm();
                  }}
                />
              </View>
            </View>
          </Pressable>
        </Pressable>
      </Modal>
    </>
  );
}

const toastStyles = StyleSheet.create({
  card: {
    alignSelf: 'stretch',
    minHeight: 52,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.x3,
    marginHorizontal: spacing.x4,
    borderRadius: radii.control,
    borderWidth: 1,
    paddingHorizontal: spacing.x4,
  },
});

const feedbackStyles = StyleSheet.create({
  scrim: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.scrim,
    padding: spacing.x6,
  },
  dialog: {
    width: '100%',
    maxWidth: 360,
    alignItems: 'center',
    gap: spacing.x3,
    padding: spacing.x5,
    borderRadius: radii.sheet,
    backgroundColor: colors.surface,
  },
  alertIcon: {
    width: 52,
    height: 52,
    borderRadius: radii.round,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.brandSoft,
  },
  center: { textAlign: 'center' },
  actions: { width: '100%', flexDirection: 'row', gap: spacing.x3 },
  action: { flex: 1 },
});
