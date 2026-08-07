import React, { useCallback } from 'react';
import { SafeAreaView } from 'react-native';
import * as ExpoSplashScreen from 'expo-splash-screen';
import { AppRouter } from './src/navigation/AppRouter';
import { AppProvider } from './src/state/AppStore';
import { styles } from './src/theme/styles';
import { AppErrorBoundary } from './src/telemetry/AppErrorBoundary';
import { SupportProvider } from './src/support/SupportStore';
import { AuthRecoveryProvider } from './src/auth/AuthRecoveryStore';
import { PreferencesProvider } from './src/preferences/PreferencesProvider';
import { usePreferences } from './src/preferences/PreferencesProvider';
import { useApp } from './src/state/AppStore';
import { useEntryIntents } from './src/navigation/useEntryIntents';

// 保持原生启动屏直到 JS 首帧渲染完成：避免冷启动时原生 splash 被瞬间替换的闪跳，
// 并遮住 expo-dev-client 下载 JS bundle 的过程（开发构建特有）。
void ExpoSplashScreen.preventAutoHideAsync();

export default function App() {
  return (
    <AppErrorBoundary>
      <AppProvider>
        <PreferencesProvider>
          <AuthRecoveryProvider>
            <SupportProvider>
              <AppSurface />
            </SupportProvider>
          </AuthRecoveryProvider>
        </PreferencesProvider>
      </AppProvider>
    </AppErrorBoundary>
  );
}

function AppSurface() {
  const { palette } = usePreferences();
  const { openEntryRoute, refreshBootstrap } = useApp();
  const resume = useCallback(() => { void refreshBootstrap(); }, [refreshBootstrap]);
  useEntryIntents(openEntryRoute, resume);
  return (
    <SafeAreaView style={[styles.safeArea, { backgroundColor: palette.background }]}>
      <AppRouter />
    </SafeAreaView>
  );
}
