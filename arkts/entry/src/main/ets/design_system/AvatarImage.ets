import { AppStore } from '../state/AppStore'
import { invalidateAssetUrl, resolveAssetUrl } from '../data/AssetUrls'
import { AppIcon, AppIconName } from './AppIcon'
import { AppColors } from '../theme/AppTokens'

// 头像显示组件。avatarUrl 兼容三种历史形态：
//  1. objectKey（`<appId>/<env>/...`）— 私有 bucket，换 presigned URL
//     （24h，见 AssetUrls 会话缓存），任何资产通用。
//  2. http(s):// — 直接显示。
//  3. data:image/... — 旧 base64 兼容。
// avatarUrl 变化（上传新头像后）必须重新 resolve——@Watch 驱动，否则
// 组件停留在旧图（"我的页不更新"的根因）。
@Component
export struct AvatarImage {
  @ObjectLink store: AppStore
  @Prop @Watch('onAvatarUrlChange') avatarUrl: string = ''
  avatarSize: number = 88

  @State resolvedUrl: string = ''
  @State failed: boolean = false

  aboutToAppear(): void {
    this.resolve()
  }

  // 上传/保存后 avatarUrl 更新 → 清旧解析结果重新换取。
  onAvatarUrlChange(): void {
    this.resolvedUrl = ''
    this.failed = false
    this.resolve()
  }

  private async resolve(): Promise<void> {
    const value = this.avatarUrl
    if (value.length === 0) return
    if (value.startsWith('http://') || value.startsWith('https://') ||
      value.startsWith('data:')) {
      this.resolvedUrl = value
      return
    }
    const url = await resolveAssetUrl(value)
    if (url === null) {
      this.failed = true
      return
    }
    this.resolvedUrl = url
  }

  build() {
    if (this.failed || this.resolvedUrl.length === 0) {
      Column() {
        AppIcon({ name: AppIconName.User, iconSize: Math.floor(this.avatarSize / 2.4),
          color: AppColors.brand })
      }
      .width(this.avatarSize).height(this.avatarSize).borderRadius(this.avatarSize / 2)
      .backgroundColor(AppColors.brandSoft)
      .justifyContent(FlexAlign.Center)
    } else {
      Image(this.resolvedUrl)
        .width(this.avatarSize).height(this.avatarSize).borderRadius(this.avatarSize / 2)
        .objectFit(ImageFit.Cover)
        .onError(() => {
          // presigned 可能过期（>24h）——清缓存，下次进入重取。
          invalidateAssetUrl(this.avatarUrl)
          this.failed = true
        })
    }
  }
}
