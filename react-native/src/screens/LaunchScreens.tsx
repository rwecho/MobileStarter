import React, { useEffect, useState } from 'react';
import { Image, Pressable, StyleSheet, Text, View } from 'react-native';
import { AppButton, OfflineBanner } from '../design-system/components';
import { PromoIllustration } from '../design-system/PromoIllustration';
import { useApp } from '../state/AppStore';
import { usePreferences } from '../preferences/PreferencesProvider';
import { colors, radii, spacing } from '../theme/tokens';
import { styles } from '../theme/styles';

export function LogoScreen() {
  const { navigate, config } = useApp();
  const { palette } = usePreferences();
  return (
    <Pressable
      accessibilityLabel="进入宣传页"
      onPress={() => navigate('launch.promo')}
      style={styles.centered}
    >
      <View style={launchStyles.logo}>
        <View style={[launchStyles.logoInner, { backgroundColor: palette.surface }]} />
      </View>
      <Text style={styles.title}>{config.brand.appName}</Text>
      <Text style={styles.secondary}>{config.brand.tagline}</Text>
      <Text style={styles.caption}>轻触继续</Text>
    </Pressable>
  );
}

export function PromoScreen() {
  const { replace, config, online } = useApp();
  const { palette } = usePreferences();
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const countdown = 3 - elapsedSeconds;
  const canSkip = config.splash.skippable && elapsedSeconds >= 1;

  useEffect(() => {
    const timers = [1, 2, 3].map((second) => setTimeout(
      () => setElapsedSeconds(second),
      second * 1000,
    ));
    return () => timers.forEach(clearTimeout);
  }, []);

  return (
    <View style={launchStyles.promo}>
      {countdown > 0 ? (
        <View
          accessibilityLabel={`倒计时 ${countdown}`}
          accessibilityLiveRegion="polite"
          style={[launchStyles.countdown, { backgroundColor: palette.surfaceMuted }]}
        >
          <Text style={styles.caption}>{countdown}</Text>
        </View>
      ) : null}
      {canSkip ? (
        <Pressable
          accessibilityLabel="跳过宣传页"
          accessibilityRole="button"
          onPress={() => replace('home')}
          style={launchStyles.skip}
        >
          <Text style={styles.secondary}>跳过</Text>
        </Pressable>
      ) : null}
      <OfflineBanner />
      <PromotionMedia uri={config.splash.imageUrl} />
      <View style={launchStyles.copy}>
        <Text style={launchStyles.badge}>{config.splash.badge}</Text>
        <Text style={styles.title}>{config.splash.title}</Text>
        <Text style={styles.secondary}>{config.splash.description}</Text>
        <Text style={styles.caption}>
          {online ? `配置版本 v${config.version}` : '离线 · 使用最近成功配置'}
        </Text>
      </View>
      <AppButton label={config.splash.actionLabel} onPress={() => replace('home')} />
    </View>
  );
}

function PromotionMedia({ uri }: Readonly<{ uri?: string | null }>) {
  const [failed, setFailed] = useState(false);
  useEffect(() => setFailed(false), [uri]);
  if (!uri || failed) return <PromoIllustration />;
  return (
    <Image
      accessibilityLabel="宣传活动图片"
      onError={() => setFailed(true)}
      resizeMode="contain"
      source={{ uri }}
      style={launchStyles.promoImage}
    />
  );
}

export function OnboardingScreen() {
  const { replace } = useApp();
  return (
    <View style={styles.centered}>
      <PromoIllustration />
      <Text style={styles.title}>三步了解核心功能</Text>
      <Text style={styles.secondary}>首次安装展示，完成后不会重复出现。</Text>
      <View style={launchStyles.fullWidth}>
        <AppButton label="完成引导" onPress={() => replace('home')} />
      </View>
    </View>
  );
}

const launchStyles = StyleSheet.create({
  logo: {
    width: 84,
    height: 84,
    borderRadius: 24,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.brand,
  },
  logoInner: {
    width: 34,
    height: 34,
    borderRadius: radii.small,
    backgroundColor: colors.surface,
    transform: [{ rotate: '45deg' }],
  },
  promo: { flex: 1, padding: spacing.x6, justifyContent: 'center', gap: spacing.x6 },
  skip: { position: 'absolute', right: spacing.x5, top: spacing.x4, padding: spacing.x3 },
  countdown: {
    alignItems: 'center',
    justifyContent: 'center',
    position: 'absolute',
    top: spacing.x4,
    left: spacing.x5,
    minWidth: 44,
    minHeight: 44,
    borderRadius: radii.round,
    backgroundColor: colors.surfaceMuted,
    opacity: 0.72,
  },
  copy: { gap: spacing.x2 },
  badge: { color: colors.brand, fontSize: 13, fontWeight: '700' },
  fullWidth: { width: '100%' },
  promoImage: { width: '100%', height: 260 },
});
