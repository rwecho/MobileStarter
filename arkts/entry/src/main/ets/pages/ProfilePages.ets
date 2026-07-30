import { AppRoute } from '../navigation/AppRoute'
import { AppStore } from '../state/AppStore'
import { AppIcon, AppIconName } from '../design_system/AppIcon'
import { AppButton, AppListRow, PageHeader } from '../design_system/Components'
import { AppColors, AppRadii, AppSpacing } from '../theme/AppTokens'

@Component
export struct ProfilePage {
  @ObjectLink store: AppStore

  build() {
    Column() {
      PageHeader({ store: this.store, title: '我的' })
      if (!this.store.signedIn) {
        Column({ space: AppSpacing.x4 }) {
          AppIcon({ name: AppIconName.User, color: AppColors.brand, iconSize: 56 })
          Text('登录后同步你的数据').fontSize(22).fontWeight(FontWeight.Bold)
          Text('会员、订单、优惠券与设置会安全同步。')
            .fontColor(AppColors.textSecondary)
          AppButton({
            label: '登录或注册',
            onTap: () => this.store.navigate(AppRoute.SignIn)
          })
        }
        .padding(AppSpacing.x6)
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
      } else {
        Scroll() {
          Column({ space: AppSpacing.x4 }) {
            AppListRow({
              store: this.store,
              label: this.store.user?.displayName ?? 'MobileUI 用户',
              value: this.store.user?.email ?? '',
              icon: AppIconName.User
            })
            Column() {
              AppListRow({
                store: this.store,
                label: '个人资料',
                route: AppRoute.ProfileEdit,
                icon: AppIconName.User
              })
              AppListRow({
                store: this.store,
                label: '会员中心',
                route: AppRoute.Membership,
                icon: AppIconName.Crown
              })
              AppListRow({
                store: this.store,
                label: '使用统计',
                route: AppRoute.Statistics,
                icon: AppIconName.Home
              })
              AppListRow({
                store: this.store,
                label: '订单管理',
                route: AppRoute.Orders,
                icon: AppIconName.Gift
              })
              AppListRow({
                store: this.store,
                label: '设置',
                route: AppRoute.Settings,
                icon: AppIconName.Settings
              })
            }
            .backgroundColor(AppColors.surface)
            .borderRadius(AppRadii.card)
            AppButton({
              label: '退出登录',
              destructive: true,
              onTap: () => this.confirmSignOut()
            })
          }
          .padding(AppSpacing.x4)
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
  }

  private confirmSignOut(): void {
    this.getUIContext().getPromptAction().showDialog({
      title: '退出登录？',
      message: '本机仍会保留非敏感偏好设置。',
      buttons: [
        { text: '取消', color: '#667085' },
        { text: '退出', color: '#D24B4B' }
      ]
    }).then(result => {
      if (result.index === 1) {
        this.store.signOut().then(() => this.store.replaceAll(AppRoute.Home))
      }
    })
  }
}

@Component
export struct MembershipPage {
  @ObjectLink store: AppStore

  build() {
    Column() {
      PageHeader({ store: this.store, title: '会员中心' })
      Column({ space: AppSpacing.x4 }) {
        Column({ space: AppSpacing.x3 }) {
          Text('PRO').fontColor(AppColors.brand).fontWeight(FontWeight.Bold)
          Text('为高频使用者准备')
            .fontColor(AppColors.surface)
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
          Text('无广告、高级主题、云端同步与优先支持。')
            .fontColor(AppColors.border)
        }
        .alignItems(HorizontalAlign.Start)
        .padding(AppSpacing.x6)
        .backgroundColor(AppColors.text)
        .borderRadius(AppRadii.card)
        Column() {
          AppListRow({
            store: this.store,
            label: '完整权益与方案对比',
            route: AppRoute.MembershipPlans,
            icon: AppIconName.Crown
          })
          AppListRow({
            store: this.store,
            label: '订阅确认',
            route: AppRoute.Checkout,
            icon: AppIconName.Check
          })
          AppListRow({
            store: this.store,
            label: '订单记录',
            route: AppRoute.Orders,
            icon: AppIconName.Gift
          })
        }
        .backgroundColor(AppColors.surface)
        .borderRadius(AppRadii.card)
      }
      .padding(AppSpacing.x4)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }
}


