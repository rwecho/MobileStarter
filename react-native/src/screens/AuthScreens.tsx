import React, { useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { AppButton, PageHeader } from '../design-system/components';
import { useApp } from '../state/AppStore';
import { colors, spacing } from '../theme/tokens';
import { styles } from '../theme/styles';
import { useTranslation } from 'react-i18next';
import { useAuthRecovery } from '../auth/AuthRecoveryStore';
import { SocialAuthButtons } from '../auth/SocialAuthButtons';

export type AuthMode = 'signIn' | 'signUp' | 'phone' | 'forgot' | 'verify' | 'reset';

export function AuthScreen({ mode }: Readonly<{ mode: AuthMode }>) {
  const {
    navigate,
    signIn,
    signUp,
    requestPhoneCode,
    verifyPhoneCode,
    showToast,
    busy: accountBusy,
    config,
    lastAuthError,
    clearAuthError,
  } = useApp();
  const { t } = useTranslation();
  const recovery = useAuthRecovery();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [username, setUsername] = useState('');
  const [code, setCode] = useState('');
  const [phone, setPhone] = useState('+86');
  const [phoneCodeSent, setPhoneCodeSent] = useState(false);
  const [agreed, setAgreed] = useState(false);
  const copy = { title: t(`auth.${mode}_title`), action: t(`auth.${mode}_action`) };
  const busy = accountBusy || recovery.busy;
  const termsRevision = config.legal.find((document) => document.type === 'terms')?.revision
    ?? 'unknown';

  const submit = async () => {
    if (mode === 'forgot') {
      await recovery.requestCode(email);
      return;
    }
    if (mode === 'verify') {
      await recovery.verifyCode(code);
      return;
    }
    if (mode === 'reset') {
      await recovery.resetPassword(password);
      return;
    }
    if (mode === 'phone') {
      if (!phoneCodeSent) {
        if (await requestPhoneCode(phone)) {
          setPhoneCodeSent(true);
          showToast(t('auth.codeSentToast'), 'success');
        }
        return;
      }
      await verifyPhoneCode(phone, code);
      return;
    }
    if ((mode === 'signIn' || mode === 'signUp') && !ensureConsent()) return;
    if (mode === 'signUp') {
      await signUp({ email, password, username, consentVersion: termsRevision });
    } else {
      await signIn({ email, password });
    }
  };

  const ensureConsent = () => {
    if (agreed) return true;
    showToast(t('auth.consentRequired'), 'info');
    return false;
  };

  return (
    <View style={styles.page}>
      <PageHeader title={copy.title} />
      <ScrollView contentContainerStyle={authStyles.content}>
        <View style={authStyles.copy}>
          <Text style={styles.title}>{copy.title}</Text>
          <Text style={styles.secondary}>{t('auth.tagline')}</Text>
        </View>
        {mode === 'signUp' ? (
          <TextInput
            accessibilityLabel={t('auth.username')}
            onChangeText={setUsername}
            placeholder={t('auth.username')}
            style={styles.input}
            value={username}
          />
        ) : null}
        {mode === 'phone' ? (
          <>
            <TextInput
              accessibilityLabel={t('auth.phone')}
              keyboardType="phone-pad"
              onChangeText={setPhone}
              placeholder={t('auth.phonePlaceholder')}
              style={styles.input}
              value={phone}
            />
            {phoneCodeSent ? (
              <TextInput
                accessibilityLabel={t('auth.smsCode')}
                keyboardType="number-pad"
                maxLength={6}
                onChangeText={setCode}
                placeholder={t('auth.smsCodePlaceholder')}
                style={styles.input}
                value={code}
              />
            ) : null}
          </>
        ) : null}
        {mode === 'signIn' || mode === 'signUp' || mode === 'forgot' ? (
          <TextInput
            accessibilityLabel={mode === 'signIn' ? t('auth.account') : t('auth.email')}
            autoCapitalize="none"
            onChangeText={(value) => { setEmail(value); clearAuthError(); }}
            placeholder={mode === 'signIn' ? t('auth.accountPlaceholder') : t('auth.email')}
            style={styles.input}
            value={email}
          />
        ) : null}
        {mode === 'verify' ? (
          <Text style={styles.secondary}>{t('auth.codeSentTo', { email: recovery.email })}</Text>
        ) : null}
        {mode !== 'forgot' && mode !== 'verify' && mode !== 'phone' ? (
          <TextInput
            accessibilityLabel={t('auth.password')}
            onChangeText={(value) => { setPassword(value); clearAuthError(); }}
            placeholder={mode === 'reset' ? t('auth.newPassword') : t('auth.password')}
            secureTextEntry
            style={styles.input}
            value={password}
          />
        ) : null}
        {mode === 'verify' ? (
          <TextInput
            accessibilityLabel={t('auth.code')}
            keyboardType="number-pad"
            maxLength={6}
            onChangeText={setCode}
            placeholder={t('auth.codePlaceholder')}
            style={styles.input}
            value={code}
          />
        ) : null}
        {lastAuthError ? (
          <Text style={authStyles.errorText}>{lastAuthError}</Text>
        ) : null}
        <AppButton
          disabled={busy || !isValid({ mode, email, password, username, code, phone, phoneCodeSent })}
          label={busy ? t('auth.processing') : mode === 'phone' && phoneCodeSent ? t('auth.verifyAndSignIn') : copy.action}
          onPress={() => void submit()}
        />
        {mode === 'signIn' ? (
          <>
            <SocialAuthButtons onBeforeAuthenticate={ensureConsent} />
            <AppButton
              label={t('auth.forgotPassword')}
              variant="secondary"
              onPress={() => navigate('auth.forgotPassword')}
            />
            <AppButton
              label={t('auth.createAccount')}
              variant="secondary"
              onPress={() => navigate('auth.signUp')}
            />
          </>
        ) : null}
        {mode === 'signIn' || mode === 'signUp' ? (
          <View style={authStyles.consentRow}>
            <Pressable
              accessibilityRole="checkbox"
              accessibilityState={{ checked: agreed }}
              accessibilityLabel={t('auth.consentCheckbox')}
              hitSlop={8}
              onPress={() => setAgreed((value) => !value)}
              style={authStyles.checkboxTarget}
            >
              <View style={[styles.checkbox, agreed && styles.checkboxChecked]}>
                {agreed ? <View style={styles.checkboxMark} /> : null}
              </View>
            </Pressable>
            <Text
              style={[styles.caption, authStyles.consentText]}
              accessibilityRole="button"
              accessibilityLabel={t('auth.consentCheckbox')}
              onPress={() => setAgreed((value) => !value)}
            >
              {t('auth.consentPrefix')}{' '}
              <Text
                accessibilityRole="link"
                onPress={() => navigate('settings.termsOfService')}
                style={authStyles.legalLinkInline}
              >{t('auth.terms')}</Text>
              {' '}{t('auth.consentMiddle')}{' '}
              <Text
                accessibilityRole="link"
                onPress={() => navigate('settings.privacyPolicy')}
                style={authStyles.legalLinkInline}
              >{t('auth.privacy')}</Text>
            </Text>
          </View>
        ) : null}
      </ScrollView>
    </View>
  );
}

type AuthInput = Readonly<{
  mode: AuthMode;
  email: string;
  password: string;
  username: string;
  code: string;
  phone: string;
  phoneCodeSent: boolean;
}>;

function isValid(input: AuthInput) {
  const { mode, email, password, username, code, phone, phoneCodeSent } = input;
  if (mode === 'phone') {
    return /^\+[1-9]\d{7,14}$/.test(phone) && (!phoneCodeSent || /^\d{6}$/.test(code));
  }
  if (mode === 'verify') return /^\d{6}$/.test(code);
  if (mode === 'reset') return password.length >= 8;
  if (mode === 'signIn') return email.trim().length >= 2 && password.length > 0;
  if (!email.includes('@')) return false;
  if (mode === 'forgot') return true;
  if (mode === 'signUp' && username.trim().length < 2) return false;
  return password.length >= 8;
}

const authStyles = StyleSheet.create({
  content: { flexGrow: 1, justifyContent: 'center', padding: spacing.x6, gap: spacing.x4 },
  copy: { gap: spacing.x2, marginBottom: spacing.x3 },
  consentRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    flexWrap: 'wrap',
    gap: spacing.x1,
  },
  checkboxTarget: { minWidth: 44, minHeight: 44, alignItems: 'center', justifyContent: 'center' },
  consentText: { flexShrink: 1 },
  legalLinkInline: { color: colors.brand },
  errorText: { color: colors.error, fontSize: 13 },
});
