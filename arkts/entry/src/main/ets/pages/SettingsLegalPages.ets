import { AppRoute } from '../navigation/AppRoute'
import { AppStore } from '../state/AppStore'
import { AppListRow, PageHeader } from '../design_system/Components'
import { AppIcon, AppIconName } from '../design_system/AppIcon'
import { AppColors, AppRadii, AppSpacing } from '../theme/AppTokens'
import { LegalDocument } from '../domain/Models'
import { lvMarkdownIn } from '@luvi/lv-markdown-in'

// 法务/关于页面——从 SettingsActionPages.ets 拆出以服从 CI 350 行硬上限。

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
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
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
      .edgeEffect(EdgeEffect.Spring)
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

