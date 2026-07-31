import React, { useEffect, useRef, useState } from 'react';
import { Image, Pressable, StyleSheet, Text, View } from 'react-native';
import { AppButton, OfflineBanner } from '../design-system/components';
import { PromoIllustration } from '../design-system/PromoIllustration';
import { useApp } from '../state/AppStore';
import { usePreferences } from '../preferences/PreferencesProvider';
import { colors, radii, spacing } from '../theme/tokens';
import { styles } from '../theme/styles';

const LogoImage = require('../../assets/splash-icon.png');

// ── Logo screen ──────────────────────────────────────────────────────
// Shows the shared brand logo while the app bootstraps, then auto‑navigates
// to the promo screen after a minimum display time. No tap required.

export function LogoScreen() {
  const { navigate, config } = useApp();
  const timer = useRef<ReturnType<typeof setTimeout>>(null);

  useEffect(() => {
    timer.current = setTimeout(() => navigate('launch.promo'), 1500);
    return () => { if (timer.current) clearTimeout(timer.current); };
  }, [navigate]);

  return (
    <View accessibilityLabel="启动中" style={styles.centered}>
      <Image
        source={LogoImage}
        style={launchStyles.logoMark}
        accessibilityLabel="品牌图标"
      />
      <Text style={styles.title}>{config.brand.appName}</Text>
      <Text style={styles.secondary}>{config.brand.tagline}</Text>
    </View>
  );
}

// ── Promo / campaign screen ──────────────────────────────────────────
// Displays the campaign artwork with a 3‑2‑1 countdown that auto‑enters
// the home screen when it reaches 0. A "跳过" button lets the user skip.

export function PromoScreen() {
  const { replace, config, online } = useApp();
  const { palette } = usePreferences();
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const countdown = 3 - elapsedSeconds;
  const canSkip = config.splash.skippable !== false;

  useEffect(() => {
    const timers = [1, 2, 3].map((sec) =>
      setTimeout(() => setElapsedSeconds(sec), sec * 1000),
    );
    return () => timers.forEach(clearTimeout);
  }, []);

  useEffect(() => {
    if (elapsedSeconds >= 3) replace('home');
  }, [elapsedSeconds, replace]);

  return (
    <View style={launchStyles.promo}>
      {countdown > 0 ? (
        <View
          accessibilityLabel={`倒计时 ${countdown}`}
          accessibilityLiveRegion="polite"
          style={[launchStyles.countdown, { backgroundColor: palette.surfaceMuted }]}
        >
          <Text style={launchStyles.countdownNumber}>{countdown}</Text>
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
      <Text style={launchStyles.autoHint}>
        {countdown > 0 ? `${countdown} 秒后自动进入` : '即将进入…'}
      </Text>
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
  logoMark: { width: 48, height: 48 },
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
    opacity: 0.72,
  },
  countdownNumber: { fontSize: 18, fontWeight: '700', color: colors.brand },
  copy: { gap: spacing.x2 },
  badge: { color: colors.brand, fontSize: 13, fontWeight: '700' },
  fullWidth: { width: '100%' },
  promoImage: { width: '100%', height: 260 },
  autoHint: {
    textAlign: 'center',
    color: colors.secondary,
    fontSize: 13,
    marginTop: spacing.x2,
  },
});
