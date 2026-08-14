import common from '@ohos.app.ability.common'
import { AppRoute } from '../navigation/AppRoute'
import { AppStore } from '../state/AppStore'
import { AppButton, AppListRow, PageHeader } from '../design_system/Components'
import { AppIcon, AppIconName } from '../design_system/AppIcon'
import { AppColors, AppRadii, AppSpacing } from '../theme/AppTokens'
import { LegalDocument } from '../domain/Models'
import { pickAvatarDataUrl, pickAvatarUri } from '../media/AvatarPicker'
import { AvatarEditor } from './AvatarEditor'
import { appString, AppString } from '../localization/AppStrings'
import { lvMarkdownIn } from '@luvi/lv-markdown-in'

@Component
export struct AccountSecurityPage {
  @ObjectLink store: AppStore
  @State currentPassword: string = ''
  @State newPassword: string = ''
  // 字段校验错误内联显示在对应输入框下方（见 issue #12 的模式）。
  @State newPasswordError: string = ''

  build() {
    Column() {
      PageHeader({ store: this.store, title: '账户与安全' })
      Column({ space: AppSpacing.x4 }) {
        AppListRow({ store: this.store, label: '登录邮箱',
          value: this.store.user?.email ?? '未登录' })
        PasswordInput({ label: '当前密码', value: this.currentPassword,
          changed: value => this.currentPassword = value })
        PasswordInput({ label: '至少 8 位新密码', value: this.newPassword,
          changed: value => {
            this.newPassword = value
            this.newPasswordError = ''
          } })
        if (this.newPasswordError.length > 0) {
          Text(this.newPasswordError)
            .fontSize(13).fontColor(AppColors.error).width('100%')
        }
        AppButton({ label: this.store.busy ? '修改中…' : '修改密码',
          icon: AppIconName.Lock, onTap: () => this.submit() })
        AppButton({ label: '退出全部设备',
          destructive: true,
          onTap: () => this.confirmSignOutAll() })
      }.padding(AppSpacing.x4).layoutWeight(1)
    }.width('100%').height('100%')
  }

  private async submit(): Promise<void> {
    if (this.newPassword.length < 8) {
      this.newPasswordError = '新密码至少需要 8 位'
      return
    }
    this.newPasswordError = ''
    if (await this.store.changePassword(this.currentPassword, this.newPassword)) {
      this.store.replaceAll(AppRoute.SignIn)
    }
  }

  private confirmSignOutAll(): void {
    this.getUIContext().getPromptAction().showDialog({
      title: '退出全部设备？',
      message: '所有设备上的登录会话将立即失效，需重新登录。',
      buttons: [
        { text: '取消', color: '#667085' },
        { text: '退出全部', color: '#D24B4B' }
      ]
    }).then(async result => {
      if (result.index === 1) {
        await this.store.signOutAll()
        this.store.replaceAll(AppRoute.SignIn)
      }
    })
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
  @State textScale: number = 1

  aboutToAppear(): void {
    const settings = this.store.user?.settings
    if (this.route === AppRoute.Appearance) this.selected = this.store.theme
    if (this.route === AppRoute.Language) this.selected = this.store.language
    if (this.route === AppRoute.TextSize) this.textScale = this.store.textScale
  }

  build() {
    Column() {
      PageHeader({ store: this.store, title: this.title() })
      Column({ space: AppSpacing.x3 }) {
        if (this.route === AppRoute.TextSize) {
          this.textSizeSlider()
        } else {
          ForEach(this.options(), (option: string) => {
            Row({ space: AppSpacing.x3 }) {
              Radio({ group: 'choice_pref', value: option })
                .checked(option === this.selected)
                .onChange((checked: boolean) => {
                  if (checked) this.selected = option
                })
              Text(this.label(option)).fontSize(16).fontColor(AppColors.text)
            }
            .width('100%').height(52).padding({ left: AppSpacing.x4 })
            .backgroundColor(AppColors.surface).borderRadius(AppRadii.card)
            .onClick(() => this.selected = option)
          })
        }
        AppButton({ label: this.store.busy
          ? appString(AppString.Saving, this.store.language)
          : appString(AppString.SaveSettings, this.store.language),
          icon: AppIconName.Check, onTap: () => this.save() })
      }.padding(AppSpacing.x4).layoutWeight(1)
    }.width('100%').height('100%')
  }

  @Builder
  textSizeSlider() {
    Column({ space: AppSpacing.x4 }) {
      Text(`${this.textScale.toFixed(2)}×`).fontSize(16).fontWeight(FontWeight.Bold)
      Slider({ value: this.textScale, min: 0.85, max: 1.3, step: 0.05 })
        .blockColor(AppColors.brand)
        .selectedColor(AppColors.brand)
        .onChange((value: number) => {
          this.textScale = value
        })
      Row() {
        Text(appString(AppString.TextSmall, this.store.language))
          .fontSize(12).fontColor(AppColors.textSecondary)
        Blank()
        Text(appString(AppString.TextExtraLarge, this.store.language))
          .fontSize(12).fontColor(AppColors.textSecondary)
      }.width('100%')
    }
    .width('100%')
  }

  private save(): void {
    if (this.route === AppRoute.Appearance) this.store.saveSetting('theme', this.selected)
    if (this.route === AppRoute.Language) this.store.saveSetting('language', this.selected)
    if (this.route === AppRoute.TextSize) this.store.saveSetting('textScale', this.textScale)
  }

  private options(): string[] {
    if (this.route === AppRoute.Appearance) return ['system', 'light', 'dark']
    if (this.route === AppRoute.Language) return ['zh-CN', 'en-US']
    return []
  }

  private label(value: string): string {
    if (value === 'system') return appString(AppString.ThemeSystem, this.store.language)
    if (value === 'light') return appString(AppString.ThemeLight, this.store.language)
    if (value === 'dark') return appString(AppString.ThemeDark, this.store.language)
    if (value === 'zh-CN') return appString(AppString.LanguageChinese, this.store.language)
    if (value === 'en-US') return appString(AppString.LanguageEnglish, this.store.language)
    if (value === '0.9') return appString(AppString.TextSmall, this.store.language)
    if (value === '1') return appString(AppString.TextStandard, this.store.language)
    if (value === '1.15') return appString(AppString.TextLarge, this.store.language)
    if (value === '1.3') return appString(AppString.TextExtraLarge, this.store.language)
    return value
  }

  private title(): string {
    if (this.route === AppRoute.Appearance) return appString(AppString.Appearance, this.store.language)
    if (this.route === AppRoute.Language) return appString(AppString.Language, this.store.language)
    return appString(AppString.TextSize, this.store.language)
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
            Row() {
              Column({ space: AppSpacing.x2 }) {
                Text(document.title).fontSize(16).fontWeight(FontWeight.Bold)
                Text(`版本 ${document.revision}`).fontSize(13).fontColor(AppColors.textSecondary)
              }
              .alignItems(HorizontalAlign.Start).layoutWeight(1)
              AppIcon({ name: AppIconName.ChevronRight, color: AppColors.textSecondary })
            }
            .padding(AppSpacing.x4)
            .backgroundColor(AppColors.surface).borderRadius(AppRadii.card)
            .onClick(() => this.openDocument(document))
          }
        })
      }.padding(AppSpacing.x4).layoutWeight(1)
    }.width('100%').height('100%')
  }

  // 入口列表：点进单篇。privacy/terms 有独立路由，其它类型（subscription）暂
  // 无专属路由，退回 LegalPage 自身不跳转。
  private openDocument(document: LegalDocument): void {
    if (document.type === 'privacy') {
      this.store.navigate(AppRoute.PrivacyPolicy)
    } else if (document.type === 'terms') {
      this.store.navigate(AppRoute.TermsOfService)
    }
  }
}

@Component
export struct LegalDocumentPage {
  @ObjectLink store: AppStore
  @Prop type: string

  build() {
    Column() {
      PageHeader({ store: this.store, title: this.title() })
      Scroll() {
        Column({ space: AppSpacing.x3 }) {
          if (this.document() === undefined) {
            Text('当前 App 尚未配置该协议文档。').fontColor(AppColors.textSecondary)
          } else {
            Text(`版本 ${this.document()?.revision ?? ''}`).fontColor(AppColors.textSecondary)
            lvMarkdownIn({ text: this.document()?.content ?? '', loadMode: 'text' })
          }
        }.alignItems(HorizontalAlign.Start).padding(AppSpacing.x4)
      }.layoutWeight(1)
    }.width('100%').height('100%')
  }

  private document(): LegalDocument | undefined {
    const documents = this.store.config?.legal ?? []
    for (let i = 0; i < documents.length; i++) {
      if (documents[i].type === this.type) return documents[i]
    }
    return undefined
  }

  private title(): string {
    return this.document()?.title ?? (this.type === 'privacy' ? '隐私政策' : '用户协议')
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
  // 头像编辑 sheet：选图后置 true 弹出 AvatarEditor（约 2/3 屏高）。
  @State showAvatarEditor: boolean = false
  @State editorImageUri: string = ''

  aboutToAppear(): void {
    this.displayName = this.store.user?.displayName ?? ''
    this.bio = this.store.user?.bio ?? ''
    this.avatarUrl = this.store.user?.avatarUrl ?? ''
  }

  build() {
    Column() {
      PageHeader({ store: this.store,
        title: appString(AppString.ProfileEdit, this.store.language) })
      Scroll() {
        Column({ space: AppSpacing.x4 }) {
          if (this.avatarUrl.length > 0) {
            Image(this.avatarUrl)
              .width(88).height(88).borderRadius(44).objectFit(ImageFit.Cover)
              .backgroundColor(AppColors.surfaceMuted)
          } else {
            Column() {
              AppIcon({ name: AppIconName.User, iconSize: 36, color: AppColors.brand })
            }
            .width(88).height(88).borderRadius(44)
            .backgroundColor(AppColors.brandSoft)
            .justifyContent(FlexAlign.Center)
          }
          AppButton({ label: appString(AppString.ChooseAvatar, this.store.language),
            icon: AppIconName.User, onTap: () => this.pickAvatar() })
          AppListRow({ store: this.store,
            label: appString(AppString.UsernameReadonly, this.store.language),
            value: `@${this.store.user?.username ?? ''}` })
          TextInput({ placeholder: appString(AppString.DisplayName, this.store.language),
            text: this.displayName })
            .height(52).maxLength(40).backgroundColor(AppColors.surface)
            .borderRadius(AppRadii.control).onChange(value => this.displayName = value)
          TextInput({ placeholder: appString(AppString.Bio, this.store.language), text: this.bio })
            .height(96).maxLength(160).backgroundColor(AppColors.surface)
            .borderRadius(AppRadii.control).onChange(value => this.bio = value)
          AppButton({ label: this.store.busy
            ? appString(AppString.Saving, this.store.language)
            : appString(AppString.SaveProfile, this.store.language),
            icon: AppIconName.Check,
            onTap: () => this.store.updateProfile(this.displayName, this.bio, this.avatarUrl) })
        }
        .padding(AppSpacing.x4)
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .justifyContent(FlexAlign.Start)
      }.layoutWeight(1)
    }
    .width('100%').height('100%')
    .bindSheet($$this.showAvatarEditor, this.avatarEditorBuilder(), {
      height: SheetSize.LARGE
    })
  }

  @Builder
  avatarEditorBuilder() {
    AvatarEditor({
      store: this.store,
      imageUri: this.editorImageUri,
      onDone: (url: string) => {
        this.showAvatarEditor = false
        this.avatarUrl = url
      },
      onCancel: () => {
        this.showAvatarEditor = false
      }
    })
  }

  private async pickAvatar(): Promise<void> {
    try {
      const uri = await pickAvatarUri()
      if (uri !== null) {
        this.editorImageUri = uri
        this.showAvatarEditor = true
      }
    } catch (error) {
      this.store.showToast('选择图片失败，请重试', true)
    }
  }
}
