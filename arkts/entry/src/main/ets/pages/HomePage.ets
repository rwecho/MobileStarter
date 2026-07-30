import { AppRoute } from '../navigation/AppRoute'
import { AppStore } from '../state/AppStore'
import { AppIcon, AppIconName } from '../design_system/AppIcon'
import { AppIconButton } from '../design_system/Components'
import { AppColors, AppRadii, AppSpacing } from '../theme/AppTokens'

@Component
export struct HomePage {
  @ObjectLink store: AppStore

  build() {
    Column() {
      Row() {
        Column() {
          Text('下午好').fontSize(13).fontColor(AppColors.textSecondary)
          Text(`欢迎使用 ${this.store.config?.brand.appName ?? 'MobileUI'}`)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        AppIconButton({
          label: '通知中心',
          icon: AppIconName.Bell,
          onTap: () => this.store.navigate(AppRoute.NotificationCenter)
        })
      }
      .height(72)
      .padding({ left: AppSpacing.x4, right: AppSpacing.x4 })
      Scroll() {
        Column({ space: AppSpacing.x5 }) {
          Row() {
            Column({ space: AppSpacing.x2 }) {
              Text('会员限时体验')
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.surface)
              Text('解锁高级功能与专属权益')
                .fontColor(AppColors.surface)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            AppIcon({
              name: AppIconName.Gift,
              color: AppColors.surface,
              iconSize: 42
            })
          }
          .height(132)
          .padding(AppSpacing.x5)
          .backgroundColor(AppColors.brand)
          .borderRadius(AppRadii.card)
          .onClick(() => this.store.navigate(AppRoute.Membership))
          QuickActions({ store: this.store })
          Text('最近动态').fontSize(20).fontWeight(FontWeight.Bold).width('100%')
          Column({ space: AppSpacing.x2 }) {
            Text('模板已准备完成').fontSize(18).fontWeight(FontWeight.Bold)
            Text('三端共享页面、状态、路由与设计令牌。')
              .fontColor(AppColors.textSecondary)
          }
          .alignItems(HorizontalAlign.Start)
          .padding(AppSpacing.x4)
          .backgroundColor(AppColors.surface)
          .borderRadius(AppRadii.card)
          Row({ space: AppSpacing.x3 }) {
            AppIcon({
              name: AppIconName.Alert,
              color: AppColors.brand,
              iconSize: 20
            })
            Column({ space: AppSpacing.x1 }) {
              Text('检查全部状态').fontWeight(FontWeight.Bold)
              Text('加载、空数据、错误、离线与未授权')
                .fontSize(13)
                .fontColor(AppColors.textSecondary)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            AppIcon({
              name: AppIconName.ChevronRight,
              color: AppColors.textSecondary,
              iconSize: 18
            })
          }
          .padding(AppSpacing.x4)
          .backgroundColor(AppColors.surface)
          .borderRadius(AppRadii.card)
          .onClick(() => this.store.navigate(AppRoute.StateGallery))
        }
        .padding(AppSpacing.x4)
      }
      .layoutWeight(1)
      BottomTabs({ store: this.store })
    }
    .width('100%')
    .height('100%')
  }
}

@Component
struct QuickActions {
  @ObjectLink store: AppStore

  build() {
    Row() {
      QuickAction({
        store: this.store,
        label: '会员',
        icon: AppIconName.Crown,
        route: AppRoute.Membership
      })
      QuickAction({
        store: this.store,
        label: '优惠券',
        icon: AppIconName.Gift,
        route: AppRoute.Coupons
      })
      QuickAction({
        store: this.store,
        label: '通知',
        icon: AppIconName.Bell,
        route: AppRoute.NotificationCenter
      })
      QuickAction({
        store: this.store,
        label: '设置',
        icon: AppIconName.Settings,
        route: AppRoute.Settings
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
  }
}

@Component
struct QuickAction {
  @ObjectLink store: AppStore
  @Prop label: string
  @Prop icon: AppIconName
  @Prop route: AppRoute

  build() {
    Column({ space: AppSpacing.x2 }) {
      Stack() {
        Rect()
          .width(52)
          .height(52)
          .radius(AppRadii.control)
          .fill(AppColors.brandSoft)
        AppIcon({ name: this.icon, color: AppColors.brand })
      }
      Text(this.label).fontSize(14)
    }
    .onClick(() => this.store.navigate(this.route))
  }
}

@Component
struct BottomTabs {
  @ObjectLink store: AppStore

  build() {
    Row() {
      TabItem({ label: '首页', icon: AppIconName.Home, active: true })
      TabItem({
        label: '会员',
        icon: AppIconName.Crown,
        onTap: () => this.store.navigate(AppRoute.Membership)
      })
      TabItem({
        label: '我的',
        icon: AppIconName.User,
        onTap: () => this.store.navigate(AppRoute.Profile)
      })
    }
    .height(66)
    .backgroundColor(AppColors.surface)
    .border({ width: { top: 1 }, color: AppColors.border })
  }
}

@Component
struct TabItem {
  @Prop label: string
  @Prop icon: AppIconName
  @Prop active: boolean = false
  onTap: () => void = () => {}

  build() {
    Column({ space: AppSpacing.x1 }) {
      AppIcon({
        name: this.icon,
        color: this.active ? AppColors.brand : AppColors.textSecondary,
        iconSize: 22
      })
      Text(this.label)
        .fontSize(12)
        .fontColor(this.active ? AppColors.brand : AppColors.textSecondary)
    }
    .layoutWeight(1)
    .onClick(this.onTap)
  }
}

