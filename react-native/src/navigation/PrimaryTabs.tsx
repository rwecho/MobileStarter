import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { AppIcon, IconName } from '../design-system/AppIcon';
import { usePreferences } from '../preferences/PreferencesProvider';
import { useApp } from '../state/AppStore';
import { spacing } from '../theme/tokens';

type PrimaryTab = 'home' | 'membership' | 'profile';

export function PrimaryTabs({ active }: Readonly<{ active: PrimaryTab }>) {
  const { replace } = useApp();
  const { locale, palette } = usePreferences();
  const labels = locale === 'en-US'
    ? { home: 'Home', membership: 'Membership', profile: 'Profile' }
    : { home: '首页', membership: '会员', profile: '我的' };
  return (
    <View style={[tabStyles.bar, { backgroundColor: palette.surface, borderTopColor: palette.border }]}>
      <Tab active={active === 'home'} icon="home" label={labels.home} onPress={() => replace('home')} />
      <Tab active={active === 'membership'} icon="crown" label={labels.membership} onPress={() => replace('membership.home')} />
      <Tab active={active === 'profile'} icon="user" label={labels.profile} onPress={() => replace('profile.home')} />
    </View>
  );
}

function Tab({ active, icon, label, onPress }: Readonly<{
  active: boolean;
  icon: IconName;
  label: string;
  onPress: () => void;
}>) {
  const { palette } = usePreferences();
  const color = active ? palette.brand : palette.textSecondary;
  return (
    <Pressable accessibilityRole="tab" accessibilityState={{ selected: active }} onPress={onPress} style={tabStyles.item}>
      <AppIcon name={icon} color={color} size={22} />
      <Text style={[tabStyles.label, { color }]}>{label}</Text>
    </Pressable>
  );
}

const tabStyles = StyleSheet.create({
  bar: {
    height: 66,
    flexDirection: 'row',
    borderTopWidth: StyleSheet.hairlineWidth,
  },
  item: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: spacing.x1 },
  label: { fontSize: 12, fontWeight: '600' },
});
