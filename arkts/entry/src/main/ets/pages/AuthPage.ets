import { AppRoute } from '../navigation/AppRoute'
import { AppStore } from '../state/AppStore'
import { AppButton, PageHeader } from '../design_system/Components'
import { AppColors, AppRadii, AppSpacing } from '../theme/AppTokens'

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

  build() {
    Column() {
      PageHeader({ store: this.store, title: this.title() })
      Column({ space: AppSpacing.x4 }) {
        Text(this.title())
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.text)
          .width('100%')
        Text('安全同步你的会员、订单与偏好设置。')
          .fontColor(AppColors.textSecondary)
          .width('100%')
        TextInput({
          placeholder: this.mode === AuthMode.Phone ? '+86 13800000000' : '邮箱',
          text: this.email
        })
          .height(52)
          .backgroundColor(AppColors.surface)
          .borderRadius(AppRadii.control)
          .onChange(value => this.email = value)
        if (this.mode !== AuthMode.Forgot &&
          (this.mode !== AuthMode.Phone || this.phoneCodeSent)) {
          TextInput({
            placeholder: this.mode === AuthMode.Verify ||
              this.mode === AuthMode.Phone ? '验证码' : '密码',
            text: this.password
          })
            .height(52)
            .type(this.mode === AuthMode.Verify ? InputType.Number : InputType.Password)
            .backgroundColor(AppColors.surface)
            .borderRadius(AppRadii.control)
            .onChange(value => this.password = value)
        }
        if (this.mode === AuthMode.SignUp) {
          TextInput({ placeholder: '用户名', text: this.username })
            .height(52)
            .backgroundColor(AppColors.surface)
            .borderRadius(AppRadii.control)
            .onChange(value => this.username = value)
        }
        AppButton({
          label: this.store.busy ? '正在处理…' : this.action(),
          onTap: () => this.submit()
        })
        if (this.mode === AuthMode.SignIn) {
          Text('其他登录方式')
            .fontSize(12)
            .fontColor(AppColors.textSecondary)
          AuthProviderRow({ store: this.store })
          Text('忘记密码')
            .fontColor(AppColors.brand)
            .onClick(() => this.store.navigate(AppRoute.ForgotPassword))
          Text('创建账号')
            .fontColor(AppColors.brand)
            .onClick(() => this.store.navigate(AppRoute.SignUp))
        }
      }
      .padding(AppSpacing.x6)
      .justifyContent(FlexAlign.Center)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
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
          this.store.showToast('密码修改成功')
          this.store.replaceAll(AppRoute.SignIn)
        }
        return
      case AuthMode.Phone:
        if (!this.phoneCodeSent) {
          if (await this.store.requestPhoneCode(this.email)) {
            this.phoneCodeSent = true
            this.store.showToast('验证码已发送')
          }
          return
        }
        if (await this.store.verifyPhoneCode(this.email, this.password)) {
          this.store.showToast('手机号登录成功')
          this.store.completeAuthentication()
        }
        return
      case AuthMode.SignUp:
        if (!await this.store.signUp(this.email, this.password, this.username)) {
          return
        }
        this.store.showToast('账号创建成功')
        this.store.completeAuthentication()
        return
      case AuthMode.SignIn:
        if (!await this.store.signIn(this.email, this.password)) {
          return
        }
        this.store.showToast('登录成功')
        this.store.completeAuthentication()
    }
  }

  private title(): string {
    switch (this.mode) {
      case AuthMode.SignIn: return '欢迎回来'
      case AuthMode.SignUp: return '创建账号'
      case AuthMode.Phone: return '手机号登录'
      case AuthMode.Forgot: return '找回密码'
      case AuthMode.Verify: return '验证邮箱'
      case AuthMode.Reset: return '设置新密码'
    }
  }

  private action(): string {
    switch (this.mode) {
      case AuthMode.SignIn: return '登录'
      case AuthMode.SignUp: return '注册'
      case AuthMode.Phone: return this.phoneCodeSent ? '验证并登录' : '发送验证码'
      case AuthMode.Forgot: return '发送验证码'
      case AuthMode.Verify: return '确认验证码'
      case AuthMode.Reset: return '确认修改'
    }
  }
}

@Component
struct AuthProviderRow {
  @ObjectLink store: AppStore

  build() {
    Row({ space: AppSpacing.x5 }) {
      AuthProviderButton({
        label: 'Apple',
        icon: $r('app.media.apple'),
        isEnabled: this.store.authProviders['apple'] === true
      })
      AuthProviderButton({
        label: 'Google',
        icon: $r('app.media.google'),
        isEnabled: this.store.authProviders['google'] === true
      })
      AuthProviderButton({
        label: 'GitHub',
        icon: $r('app.media.github'),
        isEnabled: this.store.authProviders['github'] === true
      })
      AuthProviderButton({
        label: '手机号',
        icon: $r('app.media.phone'),
        isEnabled: this.store.authProviders['phone'] === true,
        onTap: () => this.store.navigate(AppRoute.PhoneSignIn)
      })
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
  }
}

@Component
struct AuthProviderButton {
  @Prop label: string
  @Prop icon: Resource
  @Prop isEnabled: boolean = false
  onTap: () => void = () => {}

  build() {
    Column({ space: AppSpacing.x1 }) {
      Image(this.icon)
        .width(24)
        .height(24)
        .padding(14)
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
