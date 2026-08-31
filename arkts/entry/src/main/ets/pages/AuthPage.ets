import { AppRoute } from '../navigation/AppRoute'
import { AppStore } from '../state/AppStore'
import { AppButton, PageHeader } from '../design_system/Components'
import { AppString, appString } from '../localization/AppStrings'
import { AppColors, AppRadii, AppSpacing } from '../theme/AppTokens'
import { SocialAuthSheet } from './SocialAuthSheet'

export enum AuthMode {
  SignIn,
  SignUp,
  Phone,
  Forgot,
  Verify,
  Reset
}

@Component
export struct AuthPage {
  @ObjectLink store: AppStore
  @Prop mode: AuthMode
  @State email: string = ''
  @State password: string = ''
  @State username: string = ''
  @State phoneCodeSent: boolean = false
  @State consentAgreed: boolean = false
  @State socialProvider: string = ''

  build() {
    Stack() {
      Column() {
        PageHeader({ store: this.store, title: this.title() })
      Column({ space: AppSpacing.x4 }) {
        Text(this.title())
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.text)
          .width('100%')
        Text(appString(AppString.AuthTagline, this.store.language))
          .fontColor(AppColors.textSecondary)
          .width('100%')
        if (this.mode !== AuthMode.Verify && this.mode !== AuthMode.Reset) {
          TextInput({
            placeholder: this.accountPlaceholder(),
            text: this.email
          })
            .height(52)
            .backgroundColor(AppColors.surface)
            .borderRadius(AppRadii.control)
            .onChange(value => {
              this.email = value
              this.store.lastAuthError = ''
            })
            .border({ width: 1, color: AppColors.borderStrong })
        } else {
          Text(this.store.recoveryEmail)
            .fontColor(AppColors.textSecondary)
            .width('100%')
        }
        if (this.mode !== AuthMode.Forgot &&
          (this.mode !== AuthMode.Phone || this.phoneCodeSent)) {
          TextInput({
            placeholder: this.mode === AuthMode.Verify ||
              this.mode === AuthMode.Phone ? appString(AppString.AuthCode, this.store.language) :
              this.mode === AuthMode.Reset ? appString(AppString.AuthNewPassword, this.store.language) : appString(AppString.AuthPassword, this.store.language),
            text: this.password
          })
            .height(52)
            .type(this.mode === AuthMode.Verify ||
              this.mode === AuthMode.Phone ? InputType.Number : InputType.Password)
            .backgroundColor(AppColors.surface)
            .borderRadius(AppRadii.control)
            .onChange(value => {
              this.password = value
              this.store.lastAuthError = ''
            })
            .border({ width: 1, color: AppColors.borderStrong })
        }
        if (this.mode === AuthMode.SignUp) {
          TextInput({ placeholder: appString(AppString.AuthUsername, this.store.language), text: this.username })
            .height(52)
            .backgroundColor(AppColors.surface)
            .borderRadius(AppRadii.control)
            .onChange(value => this.username = value)
            .border({ width: 1, color: AppColors.borderStrong })
        }
        // 内联认证错误：紧贴表单显示，持久停留直到用户修改输入（替代底部 toast，
        // 避免被键盘遮挡/一闪而过）。见 issue #12。
        if (this.store.lastAuthError.length > 0) {
          Text(this.store.lastAuthError)
            .fontSize(13)
            .fontColor(AppColors.error)
            .width('100%')
        }
        AppButton({
          label: this.store.busy ? appString(AppString.AuthProcessing, this.store.language) : this.action(),
          onTap: () => this.submit()
        })
        if (this.mode === AuthMode.SignIn) {
          Text(appString(AppString.AuthOtherMethods, this.store.language))
            .fontSize(12)
            .fontColor(AppColors.textSecondary)
          AuthProviderRow({ store: this.store, onSocial: (provider) => this.beginSocial(provider) })
          Text(appString(AppString.AuthForgotPassword, this.store.language))
            .fontColor(AppColors.brand)
            .onClick(() => this.store.navigate(AppRoute.ForgotPassword))
          Text(appString(AppString.AuthCreateAccount, this.store.language))
            .fontColor(AppColors.brand)
            .onClick(() => this.store.navigate(AppRoute.SignUp))
        }
        if (this.requiresConsent()) {
          Row({ space: AppSpacing.x1 }) {
            Checkbox()
              .select(this.consentAgreed)
              .onChange((value: boolean) => { this.consentAgreed = value })
            Text(appString(AppString.AuthConsentPrefix, this.store.language)).fontSize(12).fontColor(AppColors.textSecondary)
              .onClick(() => { this.consentAgreed = !this.consentAgreed })
            Text(appString(AppString.AuthConsentTerms, this.store.language))
              .fontSize(12).fontColor(AppColors.brand)
              .onClick(() => this.store.navigate(AppRoute.TermsOfService))
            Text(appString(AppString.AuthConsentMiddle, this.store.language)).fontSize(12).fontColor(AppColors.textSecondary)
              .onClick(() => { this.consentAgreed = !this.consentAgreed })
            Text(appString(AppString.AuthConsentPrivacy, this.store.language))
              .fontSize(12).fontColor(AppColors.brand)
              .onClick(() => this.store.navigate(AppRoute.PrivacyPolicy))
          }
          .justifyContent(FlexAlign.Center)
          .width('100%')
        }
      }
      .padding(AppSpacing.x6)
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    if (this.socialProvider.length > 0) {
      SocialAuthSheet({
        store: this.store,
        provider: this.socialProvider,
        onDismiss: () => { this.socialProvider = '' }
      })
    }
    }
  }

  private beginSocial(provider: string): void {
    if (!this.ensureConsent()) return
    if (provider === 'phone') {
      this.store.navigate(AppRoute.PhoneSignIn)
      return
    }
    if (provider === 'apple') {
      this.store.showToast(appString(AppString.AuthAppleUnavailable, this.store.language), true)
      return
    }
    this.socialProvider = provider
  }

  private async submit(): Promise<void> {
    if (this.store.busy) {
      return
    }
    switch (this.mode) {
      case AuthMode.Forgot:
        if (await this.store.requestPasswordReset(this.email)) {
          this.store.navigate(AppRoute.VerifyEmail)
        }
        return
      case AuthMode.Verify:
        if (await this.store.verifyPasswordReset(this.password)) {
          this.store.navigate(AppRoute.ResetPassword)
        }
        return
      case AuthMode.Reset:
        if (await this.store.resetPassword(this.password)) {
          this.store.showToast(appString(AppString.AuthResetSuccess, this.store.language))
          this.store.replaceAll(AppRoute.SignIn)
        }
        return
      case AuthMode.Phone:
        if (!this.phoneCodeSent) {
          if (await this.store.requestPhoneCode(this.email)) {
            this.phoneCodeSent = true
            this.store.showToast(appString(AppString.AuthCodeSent, this.store.language))
          }
          return
        }
        if (await this.store.verifyPhoneCode(this.email, this.password)) {
          this.store.completeAuthentication()
        }
        return
      case AuthMode.SignUp:
        if (!this.ensureConsent()) return
        if (!await this.store.signUp(this.email, this.password, this.username, this.termsRevision())) {
          return
        }
        this.store.completeAuthentication()
        return
      case AuthMode.SignIn:
        if (!this.ensureConsent()) return
        if (!await this.store.signIn(this.email, this.password)) {
          return
        }
        this.store.completeAuthentication()
    }
  }

  private ensureConsent(): boolean {
    if (this.consentAgreed) return true
    this.store.showToast(appString(AppString.AuthConsentRequired, this.store.language), true)
    return false
  }

  private requiresConsent(): boolean {
    return this.mode === AuthMode.SignIn || this.mode === AuthMode.SignUp
  }

  private accountPlaceholder(): string {
    if (this.mode === AuthMode.Phone) return '+86 13800000000'
    if (this.mode === AuthMode.SignIn) return appString(AppString.AuthAccountPlaceholder, this.store.language)
    return appString(AppString.AuthEmail, this.store.language)
  }

  private termsRevision(): string {
    const legal = this.store.config?.legal ?? []
    for (let i = 0; i < legal.length; i++) {
      if (legal[i].type === 'terms') return legal[i].revision
    }
    return legal.length > 0 ? legal[0].revision : 'unknown'
  }

  private title(): string {
    switch (this.mode) {
      case AuthMode.SignIn: return appString(AppString.AuthSignInTitle, this.store.language)
      case AuthMode.SignUp: return appString(AppString.AuthSignUpTitle, this.store.language)
      case AuthMode.Phone: return appString(AppString.AuthPhoneTitle, this.store.language)
      case AuthMode.Forgot: return appString(AppString.AuthForgotTitle, this.store.language)
      case AuthMode.Verify: return appString(AppString.AuthVerifyTitle, this.store.language)
      case AuthMode.Reset: return appString(AppString.AuthResetTitle, this.store.language)
    }
  }

  private action(): string {
    switch (this.mode) {
      case AuthMode.SignIn: return appString(AppString.AuthSignInAction, this.store.language)
      case AuthMode.SignUp: return appString(AppString.AuthSignUpAction, this.store.language)
      case AuthMode.Phone: return this.phoneCodeSent ? appString(AppString.AuthVerifyAndSignIn, this.store.language) : appString(AppString.AuthPhoneAction, this.store.language)
      case AuthMode.Forgot: return appString(AppString.AuthForgotAction, this.store.language)
      case AuthMode.Verify: return appString(AppString.AuthVerifyAction, this.store.language)
      case AuthMode.Reset: return appString(AppString.AuthResetAction, this.store.language)
    }
  }
}

@Component
struct AuthProviderRow {
  @ObjectLink store: AppStore
  onSocial: (provider: string) => void = () => {}

  build() {
    Row({ space: AppSpacing.x5 }) {
      AuthProviderButton({
        label: 'Apple',
        icon: $r('app.media.apple'),
        iconStyle: AuthIconStyle.Monochrome,
        isEnabled: this.store.authProviders['apple'] === true,
        onTap: () => this.onSocial('apple')
      })
      AuthProviderButton({
        label: 'Google',
        icon: $r('app.media.google'),
        iconStyle: AuthIconStyle.Branded,
        isEnabled: this.store.authProviders['google'] === true,
        onTap: () => this.onSocial('google')
      })
      AuthProviderButton({
        label: 'GitHub',
        icon: $r('app.media.github'),
        iconStyle: AuthIconStyle.Monochrome,
        isEnabled: this.store.authProviders['github'] === true,
        onTap: () => this.onSocial('github')
      })
      AuthProviderButton({
        label: appString(AppString.AuthPhone, this.store.language),
        icon: $r('app.media.phone'),
        iconStyle: AuthIconStyle.Monochrome,
        isEnabled: this.store.authProviders['phone'] === true,
        onTap: () => this.onSocial('phone')
      })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
  }
}

enum AuthIconStyle {
  Branded,
  Monochrome
}

@Component
struct AuthProviderButton {
  @Prop label: string
  @Prop icon: Resource
  @Prop iconStyle: AuthIconStyle = AuthIconStyle.Monochrome
  @Prop isEnabled: boolean = false
  onTap: () => void = () => {}

  build() {
    Column({ space: AppSpacing.x1 }) {
      Column() {
        if (this.iconStyle === AuthIconStyle.Monochrome) {
          Image(this.icon)
            .width(24)
            .height(24)
            .fillColor(AppColors.text)
        } else {
          Image(this.icon)
            .width(24)
            .height(24)
        }
      }
        .width(52)
        .height(52)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppColors.surface)
        .border({ width: 1, color: AppColors.border })
        .borderRadius(26)
      Text(this.label).fontSize(12).fontColor(AppColors.textSecondary)
    }
    .opacity(this.isEnabled ? 1 : 0.38)
    .enabled(this.isEnabled)
    .onClick(this.onTap)
  }
}
