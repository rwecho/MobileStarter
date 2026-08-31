import React, { useEffect, useState } from 'react';
import { Image, Pressable, StyleSheet, Text, View } from 'react-native';
import { AppCard } from '../design-system/components';
import { invalidateAssetUrl, resolveAssetUrl } from '../data/apiClient';
import { usePreferences } from '../preferences/PreferencesProvider';
import { colors, radii, spacing } from '../theme/tokens';
import { styles } from '../theme/styles';

export function ProfileIdentityCard({
  displayName,
  username,
  email,
  bio,
  avatarUrl,
  onAvatarPress,
}: Readonly<{
  displayName: string;
  username: string;
  email: string;
  bio: string;
  avatarUrl?: string | null;
  onAvatarPress?: () => void;
}>) {
  const { palette } = usePreferences();
  const avatar = (
    <ProfileAvatar
      avatarUrl={avatarUrl}
      label={displayName.slice(0, 1).toUpperCase()}
    />
  );
  return (
    <AppCard>
      <View style={identityStyles.container}>
        {onAvatarPress ? (
          <Pressable
            accessibilityLabel="更换头像"
            accessibilityRole="button"
            onPress={onAvatarPress}
            style={identityStyles.avatarAction}
          >
            {avatar}
            <Text style={identityStyles.avatarHint}>点击更换</Text>
          </Pressable>
        ) : avatar}
        <View style={identityStyles.copy}>
          <Text style={styles.heading}>{displayName}</Text>
          <Text style={styles.caption}>@{username}</Text>
          <Text style={styles.secondary}>{email}</Text>
        </View>
        <Text
          style={[
            identityStyles.bio,
            { backgroundColor: palette.surfaceMuted, color: palette.textSecondary },
          ]}
        >
          {bio || '这个人还没有填写简介。'}
        </Text>
      </View>
    </AppCard>
  );
}

// 头像显示：avatarUrl 兼容 objectKey（→ presigned 24h）/ http(s) / data: 三种
// 形态，显示前必须经 resolveAssetUrl 换取（objectKey 不是可渲染 URI）。
// avatarUrl 变化（上传新头像后）清旧解析结果重新换取。
function ProfileAvatar({
  avatarUrl,
  label,
}: Readonly<{ avatarUrl?: string | null; label: string }>) {
  const { palette } = usePreferences();
  const [resolved, setResolved] = useState<string | null>(null);
  useEffect(() => {
    let alive = true;
    setResolved(null);
    if (!avatarUrl) return;
    void resolveAssetUrl(avatarUrl).then(url => {
      if (alive) setResolved(url);
    });
    return () => { alive = false; };
  }, [avatarUrl]);
  if (resolved) {
    return (
      <Image
        accessibilityLabel="用户头像"
        source={{ uri: resolved }}
        style={identityStyles.avatar}
        onError={() => {
          // presigned 可能过期（>24h）——清缓存，下次进入重取。
          if (avatarUrl) invalidateAssetUrl(avatarUrl);
          setResolved(null);
        }}
      />
    );
  }
  return (
    <View style={[identityStyles.avatar, { backgroundColor: palette.brandSoft }]}>
      <Text style={identityStyles.avatarText}>{label}</Text>
    </View>
  );
}

const identityStyles = StyleSheet.create({
  container: { alignItems: 'center', gap: spacing.x3, paddingVertical: spacing.x3 },
  copy: { alignItems: 'center', gap: spacing.x1 },
  bio: {
    color: colors.textSecondary,
    textAlign: 'center',
    width: '100%',
    padding: spacing.x3,
    borderRadius: radii.control,
    backgroundColor: colors.surfaceMuted,
  },
  avatarAction: { alignItems: 'center', gap: spacing.x2 },
  avatarHint: { color: colors.brand, fontWeight: '700' },
  avatar: {
    width: 96,
    height: 96,
    borderRadius: radii.round,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.brandSoft,
  },
  avatarText: { color: colors.brand, fontSize: 20, fontWeight: '700' },
});
