import React from 'react';
import { Platform } from 'react-native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
// Native bottom tabs（iOS UITabBarController / Android BottomNavigationView）：已并入
// bottom-tabs 本体，7.18+ 位于 /unstable 子路径。要求 react-native-screens ≥ 4.25 与
// dev-client 构建（不支持 Expo Go）。web 无原生 tab bar，按官方指引回退 JS 版 navigator。
import { createNativeBottomTabNavigator } from '@react-navigation/bottom-tabs/unstable';
import { useTranslation } from 'react-i18next';
import { HomeScreen } from '../screens/HomeScreen';
import { ProfileScreen } from '../screens/ProfileScreens';
import { AppIcon } from '../design-system/AppIcon';
import { colors } from '../theme/tokens';

type TabParamList = { home: undefined; 'profile.home': undefined };

const NativeTabs = createNativeBottomTabNavigator<TabParamList>();
const WebTabs = createBottomTabNavigator<TabParamList>();

// 底部 tab 壳，对齐 Flutter StatefulShellRoute.indexedStack / ArkTS Tabs：
// 只承载首页/我的两个常驻 tab（各自保活、切换不重置状态），其余路由由
// RootNavigator push 覆盖在壳之上（子页面无 tab bar，与两端一致）。
export function AppTabs() {
  const { t } = useTranslation();
  if (Platform.OS === 'web') {
    return (
      <WebTabs.Navigator
        screenOptions={{ headerShown: false, tabBarActiveTintColor: colors.brand }}
      >
        <WebTabs.Screen
          name="home"
          component={HomeScreen}
          options={{
            tabBarLabel: t('tabs.home'),
            tabBarIcon: ({ color, size }) => (
              <AppIcon name="home" color={color} size={size} />
            ),
          }}
        />
        <WebTabs.Screen
          name="profile.home"
          component={ProfileScreen}
          options={{
            tabBarLabel: t('tabs.profile'),
            tabBarIcon: ({ color, size }) => (
              <AppIcon name="user" color={color} size={size} />
            ),
          }}
        />
      </WebTabs.Navigator>
    );
  }
  return (
    <NativeTabs.Navigator screenOptions={{ tabBarActiveTintColor: colors.brand }}>
      {/* 原生 tab bar 图标只接受原生资源（不支持 RN 组件/SVG）：iOS 用系统 SF Symbols；
          Android 用 metro 管理的 PNG 剪影（assets/tab-icons，由设计 SVG 生成，渲染时系统 tint）。 */}
      <NativeTabs.Screen
        name="home"
        component={HomeScreen}
        options={{
          tabBarLabel: t('tabs.home'),
          tabBarIcon: Platform.select({
            ios: { type: 'sfSymbol', name: 'house' },
            android: { type: 'image', source: require('../../assets/tab-icons/home.png') },
          }),
        }}
      />
      <NativeTabs.Screen
        name="profile.home"
        component={ProfileScreen}
        options={{
          tabBarLabel: t('tabs.profile'),
          tabBarIcon: Platform.select({
            ios: { type: 'sfSymbol', name: 'person' },
            android: { type: 'image', source: require('../../assets/tab-icons/user.png') },
          }),
        }}
      />
    </NativeTabs.Navigator>
  );
}
