import { AppStore } from '../state/AppStore'
import { AsyncStatus } from '../state/AsyncState'
import { AppButton, AppListRow, PageHeader } from '../design_system/Components'
import { AppColors, AppRadii, AppSpacing } from '../theme/AppTokens'
import { OrderView, SessionView } from '../domain/Models'

@Component
export struct SessionsPage {
  @ObjectLink store: AppStore

  aboutToAppear(): void {
    this.store.remote.loadSessions()
  }

  build() {
    Column() {
      PageHeader({ store: this.store, title: '登录设备管理' })
      if (this.store.remote.sessionState.status === AsyncStatus.Loading) {
        LoadingProgress().width(40).height(40).layoutWeight(1)
      } else if (this.store.remote.sessionState.status === AsyncStatus.Empty) {
        EmptyCopy({ message: '没有活动登录设备。', retry: () => this.store.remote.loadSessions() })
      } else if (this.store.remote.sessionState.status === AsyncStatus.Success) {
        List({ space: AppSpacing.x3 }) {
          ForEach(this.store.remote.sessionState.data ?? [], (session: SessionView) => {
            ListItem() {
              Column() {
                AppListRow({ store: this.store, label: session.deviceName,
                  value: session.current ? '当前设备' : '已登录设备' })
                if (!session.current) {
                  Button('撤销').onClick(() => this.store.remote.revokeSession(session.id))
                    .backgroundColor(Color.Transparent).fontColor(AppColors.error)
                }
              }.backgroundColor(AppColors.surface).borderRadius(AppRadii.card)
            }
          })
        }.padding(AppSpacing.x4).layoutWeight(1)
      } else {
        EmptyCopy({ message: this.store.remote.sessionState.message ?? '加载失败，请重试。',
          retry: () => this.store.remote.loadSessions() })
      }
    }.width('100%').height('100%')
  }
}

@Component
export struct OrdersPage {
  @ObjectLink store: AppStore

  aboutToAppear(): void {
    this.store.remote.loadOrders()
  }

  build() {
    Column() {
      PageHeader({ store: this.store, title: '订单管理' })
      if (this.store.remote.orderState.status === AsyncStatus.Loading) {
        LoadingProgress().width(40).height(40).layoutWeight(1)
      } else if (this.store.remote.orderState.status === AsyncStatus.Empty) {
        EmptyCopy({ message: '当前账户暂无订单。', retry: () => this.store.remote.loadOrders() })
      } else if (this.store.remote.orderState.status === AsyncStatus.Success) {
        List({ space: AppSpacing.x3 }) {
          ForEach(this.store.remote.orderState.data ?? [], (order: OrderView) => {
            ListItem() {
              Column({ space: AppSpacing.x2 }) {
                Text(order.planId).fontSize(18).fontWeight(FontWeight.Bold)
                Text(`${order.currency} ${(order.amountMinor / 100).toFixed(2)}`)
                Text(order.status).fontColor(AppColors.textSecondary)
              }
              .alignItems(HorizontalAlign.Start)
              .padding(AppSpacing.x4)
              .backgroundColor(AppColors.surface)
              .borderRadius(AppRadii.card)
            }
          })
        }.padding(AppSpacing.x4).layoutWeight(1)
      } else {
        EmptyCopy({ message: this.store.remote.orderState.message ?? '加载失败，请重试。',
          retry: () => this.store.remote.loadOrders() })
      }
    }.width('100%').height('100%')
  }
}

@Component
struct EmptyCopy {
  @Prop message: string
  retry: () => void = () => {}
  build() {
    Column({ space: AppSpacing.x3 }) {
      Text(this.message).fontColor(AppColors.textSecondary)
      AppButton({ label: '重试', onTap: this.retry })
    }.padding(AppSpacing.x6).justifyContent(FlexAlign.Center).layoutWeight(1)
  }
}

