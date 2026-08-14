import { AppStore } from '../state/AppStore'
import { HomePage } from './HomePage'
import { ProfilePage } from './ProfilePages'
import { AppIcon, AppIconName } from '../design_system/AppIcon'
import { AppColors, AppSpacing } from '../theme/AppTokens'
import { localized } from '../localization/AppStrings'

// 底部 tab 壳：首页/我的 常驻两个 TabContent，用 Tabs 组件保活（切换原地、
// 无翻页转场、不销毁重建）。它是 navStack 的 'tabs' NavDestination，子页面
// （设置/详情等）由 navStack push 覆盖在它之上。
@Component
export struct AppTabShell {
  @ObjectLink store: AppStore
  @State currentIndex: number = 0

  aboutToAppear(): void {
    this.currentIndex = this.store.currentTab
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        HomePage({ store: this.store })
      }
      .tabBar(this.tabBar(0, AppIconName.Home, '首页', 'Home'))
      TabContent() {
        ProfilePage({ store: this.store })
      }
      .tabBar(this.tabBar(1, AppIconName.User, '我的', 'Profile'))
    }
    .onChange((index: number) => {
      this.currentIndex = index
      this.store.currentTab = index
    })
    .barHeight(64)
    .backgroundColor(AppColors.background)
  }

  @Builder
  tabBar(index: number, icon: AppIconName, zh: string, en: string) {
    Column({ space: AppSpacing.x1 }) {
      AppIcon({
        name: icon,
        color: this.currentIndex === index ? AppColors.brand : AppColors.textSecondary,
        iconSize: 22
      })
      Text(localized(zh, en, this.store.language))
        .fontSize(12)
        .fontColor(this.currentIndex === index ? AppColors.brand : AppColors.textSecondary)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }
}
