import { AppRoute } from '../navigation/AppRoute'
import { AppStore } from '../state/AppStore'
import { AppButton, AppListRow, PageHeader } from '../design_system/Components'
import { AppIconName } from '../design_system/AppIcon'
import { AppColors, AppRadii, AppSpacing } from '../theme/AppTokens'
import { LegalDocument } from '../domain/Models'

@Component
export struct AccountSecurityPage {
  @ObjectLink store: AppStore
  @State currentPassword: string = ''
  @State newPassword: string = ''

  build() {
    Column() {
      PageHeader({ store: this.store, title: '账户与安全' })
      Column({ space: AppSpacing.x4 }) {
        AppListRow({ store: this.store, label: '登录邮箱',
          value: this.store.user?.email ?? '未登录' })
        PasswordInput({ label: '当前密码', value: this.currentPassword,
          changed: value => this.currentPassword = value })
        PasswordInput({ label: '至少 8 位新密码', value: this.newPassword,
          changed: value => this.newPassword = value })
        AppButton({ label: this.store.busy ? '修改中…' : '修改密码',
          icon: AppIconName.Lock, onTap: () => this.submit() })
      }.padding(AppSpacing.x4).layoutWeight(1)
    }.width('100%').height('100%')
  }

  private async submit(): Promise<void> {
    if (this.newPassword.length < 8) {
      this.store.showToast('新密码至少需要 8 位', true)
      return
    }
    if (await this.store.changePassword(this.currentPassword, this.newPassword)) {
      this.store.replaceAll(AppRoute.SignIn)
    }
  }
}

@Component
struct PasswordInput {
  @Prop label: string
  @Prop value: string
  changed: (value: string) => void = () => {}
  build() {
    TextInput({ placeholder: this.label, text: this.value })
      .height(52).type(InputType.Password).backgroundColor(AppColors.surface)
      .borderRadius(AppRadii.control).onChange(this.changed)
  }
}

@Component
export struct ChoicePreferencePage {
  @ObjectLink store: AppStore
  @Prop route: AppRoute
  @State selected: string = ''

  aboutToAppear(): void {
    const settings = this.store.user?.settings
    if (this.route === AppRoute.Appearance) this.selected = String(settings?.['theme'] ?? 'system')
    if (this.route === AppRoute.Language) this.selected = String(settings?.['language'] ?? 'zh-CN')
    if (this.route === AppRoute.TextSize) this.selected = String(settings?.['textScale'] ?? 1)
  }

  build() {
    Column() {
      PageHeader({ store: this.store, title: this.title() })
      Column({ space: AppSpacing.x3 }) {
        ForEach(this.options(), (option: string) => {
          Button(this.label(option))
            .width('100%').height(52)
            .fontColor(option === this.selected ? AppColors.surface : AppColors.text)
            .backgroundColor(option === this.selected ? AppColors.brand : AppColors.surface)
            .onClick(() => this.selected = option)
        })
        AppButton({ label: this.store.busy ? '保存中…' : '保存设置',
          icon: AppIconName.Check, onTap: () => this.save() })
      }.padding(AppSpacing.x4).layoutWeight(1)
    }.width('100%').height('100%')
  }

  private save(): void {
    if (this.route === AppRoute.Appearance) this.store.saveSetting('theme', this.selected)
    if (this.route === AppRoute.Language) this.store.saveSetting('language', this.selected)
    if (this.route === AppRoute.TextSize) this.store.saveSetting('textScale', Number(this.selected))
  }

  private options(): string[] {
    if (this.route === AppRoute.Appearance) return ['system', 'light', 'dark']
    if (this.route === AppRoute.Language) return ['zh-CN', 'en-US']
    return ['0.9', '1', '1.15', '1.3']
  }

  private label(value: string): string {
    if (value === 'system') return '跟随系统'
    if (value === 'light') return '浅色'
    if (value === 'dark') return '深色'
    if (value === 'zh-CN') return '简体中文'
    if (value === 'en-US') return 'English'
    if (value === '0.9') return '较小'
    if (value === '1') return '标准'
    if (value === '1.15') return '较大'
    if (value === '1.3') return '特大'
    return value
  }

  private title(): string {
    if (this.route === AppRoute.Appearance) return '外观主题'
    if (this.route === AppRoute.Language) return '语言'
    return '字体大小'
  }
}

@Component
export struct LegalPage {
  @ObjectLink store: AppStore
  build() {
    Column() {
      PageHeader({ store: this.store, title: '协议与政策' })
      List({ space: AppSpacing.x3 }) {
        ForEach(this.store.config?.legal ?? [], (document: LegalDocument) => {
          ListItem() {
            Column({ space: AppSpacing.x2 }) {
              Text(document.title).fontSize(18).fontWeight(FontWeight.Bold)
              Text(`版本 ${document.revision}`).fontColor(AppColors.textSecondary)
              Text(document.content).fontColor(AppColors.text)
            }
            .alignItems(HorizontalAlign.Start).padding(AppSpacing.x4)
            .backgroundColor(AppColors.surface).borderRadius(AppRadii.card)
          }
        })
      }.padding(AppSpacing.x4).layoutWeight(1)
    }.width('100%').height('100%')
  }
}

@Component
export struct AboutPage {
  @ObjectLink store: AppStore
  build() {
    Column() {
      PageHeader({ store: this.store, title: '关于与版本' })
      Column() {
        AppListRow({ store: this.store, label: '产品',
          value: this.store.config?.brand.appName ?? 'MobileUI' })
        AppListRow({ store: this.store, label: '客户端版本', value: '1.0.0 (1)' })
        AppListRow({ store: this.store, label: '配置版本',
          value: `v${this.store.config?.version ?? 0}` })
        AppListRow({ store: this.store, label: '服务状态',
          value: this.store.online ? '在线' : '离线缓存' })
      }.margin(AppSpacing.x4).backgroundColor(AppColors.surface).borderRadius(AppRadii.card)
    }.width('100%').height('100%')
  }
}

@Component
export struct ProfileEditPage {
  @ObjectLink store: AppStore
  @State displayName: string = ''
  @State bio: string = ''
  @State avatarUrl: string = ''

  aboutToAppear(): void {
    this.displayName = this.store.user?.displayName ?? ''
    this.bio = this.store.user?.bio ?? ''
    this.avatarUrl = this.store.user?.avatarUrl ?? ''
  }

  build() {
    Column() {
      PageHeader({ store: this.store, title: '个人资料' })
      Column({ space: AppSpacing.x4 }) {
        AppListRow({ store: this.store, label: '用户名（不可修改）',
          value: `@${this.store.user?.username ?? ''}` })
        TextInput({ placeholder: '显示名称', text: this.displayName })
          .height(52).backgroundColor(AppColors.surface).borderRadius(AppRadii.control)
          .onChange(value => this.displayName = value)
        TextInput({ placeholder: '个人简介', text: this.bio })
          .height(72).backgroundColor(AppColors.surface).borderRadius(AppRadii.control)
          .onChange(value => this.bio = value)
        TextInput({ placeholder: '头像 HTTPS 地址', text: this.avatarUrl })
          .height(52).backgroundColor(AppColors.surface).borderRadius(AppRadii.control)
          .onChange(value => this.avatarUrl = value)
        AppButton({ label: this.store.busy ? '保存中…' : '保存资料',
          icon: AppIconName.Check,
          onTap: () => this.store.updateProfile(this.displayName, this.bio, this.avatarUrl) })
      }.padding(AppSpacing.x4).layoutWeight(1)
    }.width('100%').height('100%')
  }
}
