import { AppStore } from '../state/AppStore'
import { apiClient } from '../data/ApiClient'
import { AppButton } from '../design_system/Components'
import { AppIconName } from '../design_system/AppIcon'
import { AppColors, AppRadii, AppSpacing } from '../theme/AppTokens'
import { ImageSize, cropToJpegBytes, readImageSize } from '../media/AvatarPicker'

// 头像编辑 sheet 内容：方形预览 + 双指缩放 / 单指拖拽定位，确认后按手势
// 计算原图方形区域 → 512×512 JPEG → POST /storage/uploads + PUT 直传 OSS。
// 由宿主页 bindSheet（约 2/3 屏高）承载。
@Component
export struct AvatarEditor {
  @ObjectLink store: AppStore
  imageUri: string = ''
  // 上传完成（url = 对象访问 URL）；取消。
  onDone: (url: string) => void = () => {}
  onCancel: () => void = () => {}

  @State zoomScale: number = 1
  @State offsetX: number = 0
  @State offsetY: number = 0
  @State busy: boolean = false
  @State side: number = 320
  private origW: number = 0
  private origH: number = 0
  private baseScale: number = 1
  private baseOffsetX: number = 0
  private baseOffsetY: number = 0

  aboutToAppear(): void {
    // 媒体库 uri 需经 fs.open → fd（issue #21），统一走 readImageSize。
    readImageSize(this.imageUri).then((size: ImageSize) => {
      this.origW = size.width
      this.origH = size.height
    }).catch(() => {
      // 读不到尺寸时 confirm 会因 origW=0 拒绝，不至于崩溃。
    })
  }

  // Contain 适配系数：图完整显示在 side×side 内的基础缩放。
  private fitK(): number {
    if (this.origW === 0 || this.origH === 0) return 1
    return Math.min(this.side / this.origW, this.side / this.origH)
  }

  private dispW(): number {
    // 原图尺寸未读回前先铺满方形区（否则 0×0 → 一片黑）。
    if (this.origW === 0) return this.side
    return this.origW * this.fitK() * this.zoomScale
  }

  private dispH(): number {
    if (this.origH === 0) return this.side
    return this.origH * this.fitK() * this.zoomScale
  }

  // 缩放/拖拽后图中心相对方形中心的最大允许偏移（图边不出窗口）。
  private clampOffsetX(x: number): number {
    const max = Math.max(0, (this.dispW() - this.side) / 2)
    return Math.max(-max, Math.min(max, x))
  }

  private clampOffsetY(y: number): number {
    const max = Math.max(0, (this.dispH() - this.side) / 2)
    return Math.max(-max, Math.min(max, y))
  }

  build() {
    Column({ space: AppSpacing.x4 }) {
      Text('编辑头像').fontSize(18).fontWeight(FontWeight.Bold).fontColor(AppColors.text)
      // 方形编辑区：黑底 + 图 + 中央方形描边（标记裁剪窗口）。
      // 注意：不能叠全覆盖遮罩（会整体压黑，之前"黑屏"的根因）。
      Stack() {
        Image(this.imageUri)
          .width(this.dispW()).height(this.dispH())
          .objectFit(ImageFit.Fill)
          .translate({ x: this.offsetX, y: this.offsetY })
          .gesture(
            PinchGesture({ fingers: 2 })
              .onActionStart(() => {
                this.baseScale = this.zoomScale
              })
              .onActionUpdate((event: GestureEvent) => {
                const next = this.baseScale * event.scale
                this.zoomScale = Math.max(1, Math.min(4, next))
                this.offsetX = this.clampOffsetX(this.offsetX)
                this.offsetY = this.clampOffsetY(this.offsetY)
              })
          )
          .gesture(
            PanGesture({ fingers: 1 })
              .onActionStart(() => {
                this.baseOffsetX = this.offsetX
                this.baseOffsetY = this.offsetY
              })
              .onActionUpdate((event: GestureEvent) => {
                this.offsetX = this.clampOffsetX(this.baseOffsetX + event.offsetX)
                this.offsetY = this.clampOffsetY(this.baseOffsetY + event.offsetY)
              })
          )
      }
      .width(this.side).height(this.side)
      .backgroundColor('#000000')
      .borderRadius(AppRadii.card)
      .clip(true)
      .onAreaChange((_old: Area, newArea: Area) => {
        // 首次布局拿到实际方形边长，重置手势基准。
        const w = Number(newArea.width)
        if (w > 0 && Math.abs(w - this.side) > 0.5) {
          this.side = w
          this.zoomScale = 1
          this.offsetX = 0
          this.offsetY = 0
        }
      })

      Text('双指缩放 · 单指拖拽调整构图').fontSize(12).fontColor(AppColors.textSecondary)

      Row({ space: AppSpacing.x3 }) {
        AppButton({ label: '取消', onTap: () => this.onCancel() })
        AppButton({
          label: this.busy ? '上传中…' : '确认并上传',
          icon: AppIconName.Check,
          onTap: () => this.confirm()
        })
      }.width('100%')
    }
    .width('100%')
    .padding(AppSpacing.x5)
  }

  private async confirm(): Promise<void> {
    if (this.busy || this.origW === 0) return
    this.busy = true
    try {
      // 手势 → 原图方形区域。图左上角显示坐标 = 中心 - 半尺寸 + 偏移；
      // 反解到原图坐标除以总显示缩放（fitK × scale）。
      const k = this.fitK() * this.zoomScale
      const left = this.side / 2 - this.dispW() / 2 + this.offsetX
      const top = this.side / 2 - this.dispH() / 2 + this.offsetY
      let sideOrig = Math.min(this.side / k, Math.min(this.origW, this.origH))
      sideOrig = Math.max(1, Math.floor(sideOrig))
      let rx = Math.floor(-left / k)
      let ry = Math.floor(-top / k)
      rx = Math.max(0, Math.min(this.origW - sideOrig, rx))
      ry = Math.max(0, Math.min(this.origH - sideOrig, ry))

      // 裁剪 → 512×512 JPEG bytes（fd 方式打开媒体库 uri，issue #21）。
      const packed: ArrayBuffer = await cropToJpegBytes(this.imageUri, {
        x: rx, y: ry, width: sideOrig, height: sideOrig
      })

      // 上传：avatars/<userId>-<时间戳>.jpg（时间戳避免 URL 缓存）。
      const userId = this.store.user?.id ?? 'anon'
      const path = `avatars/${userId}-${Date.now()}.jpg`
      const sign = await apiClient.signUpload(path, 'image/jpeg')
      await apiClient.uploadToS3(sign.uploadUrl, packed, 'image/jpeg')
      this.busy = false
      // 私有 bucket：存 objectKey，显示层经 /storage/urls 换 presigned URL。
      this.onDone(sign.objectKey)
    } catch (error) {
      this.busy = false
      this.store.showToast(error instanceof Error ? error.message : '头像上传失败', true)
    }
  }
}
