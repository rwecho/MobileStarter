import React from 'react';
import { SafeAreaView } from 'react-native';
import { AppRouter } from './src/navigation/AppRouter';
import { AppProvider } from './src/state/AppStore';
import { styles } from './src/theme/styles';
import { AppErrorBoundary } from './src/telemetry/AppErrorBoundary';
import { SupportProvider } from './src/support/SupportStore';
import { AuthRecoveryProvider } from './src/auth/AuthRecoveryStore';
import { PreferencesProvider } from './src/preferences/PreferencesProvider';
import { usePreferences } from './src/preferences/PreferencesProvider';

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
  return (
    <SafeAreaView style={[styles.safeArea, { backgroundColor: palette.background }]}>
      <AppRouter />
    </SafeAreaView>
  );
}
