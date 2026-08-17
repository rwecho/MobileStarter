import image from '@ohos.multimedia.image'
import { AppStore } from '../state/AppStore'
import { apiClient } from '../data/ApiClient'
import { AppButton } from '../design_system/Components'
import { AppIconName } from '../design_system/AppIcon'
import { AppColors, AppRadii, AppSpacing } from '../theme/AppTokens'
import { telemetry, TelemetryValue } from '../telemetry/Telemetry'
import { CropRegion, NormalizedImage, cropToJpegBytes, loadNormalizedImage } from '../media/AvatarPicker'

// 头像编辑 sheet 内容：方形预览 + 双指缩放 / 单指拖拽定位，确认后按手势
// 计算方形区域 → 512×512 JPEG → POST /storage/uploads + PUT 直传 OSS。
// 由宿主页 bindSheet（约 2/3 屏高）承载。
// 显示与裁剪共用归一化图（EXIF 已转正的 PixelMap + 同空间 bytes），
// 彻底规避 Image(uri) 与 fd 解码的 EXIF/尺寸歧义（变形根因）。
@Component
export struct AvatarEditor {
  @ObjectLink store: AppStore
  imageUri: string = ''
  // 上传完成（objectKey）；取消。
  onDone: (objectKey: string) => void = () => {}
  onCancel: () => void = () => {}

  @State zoomScale: number = 1
  @State offsetX: number = 0
  @State offsetY: number = 0
  @State busy: boolean = false
  // sheet 内联错误（全局 toast 会被 sheet 遮住，必须自己展示）。
  @State error: string = ''
  @State side: number = 320
  // 归一化结果必须 @State：异步读回后驱动 UI 重算尺寸。
  @State pixelMap: image.PixelMap | null = null
  @State origW: number = 0
  @State origH: number = 0
  private normalized: NormalizedImage | null = null
  private baseScale: number = 1
  private baseOffsetX: number = 0
  private baseOffsetY: number = 0

  aboutToAppear(): void {
    loadNormalizedImage(this.imageUri).then((img: NormalizedImage) => {
      this.normalized = img
      this.pixelMap = img.pixelMap
      this.origW = img.width
      this.origH = img.height
    }).catch(() => {
      // 归一化失败时 confirm 因 origW=0 拒绝，不至于崩溃。
    })
  }

  aboutToDisappear(): void {
    // 归一化 PixelMap 由编辑器持有，sheet 关闭即释放（bytes 随对象回收）。
    this.normalized?.pixelMap.release()
    this.normalized = null
  }

  // Contain 适配系数：图完整显示在 side×side 内的基础缩放。
  private fitK(): number {
    if (this.origW === 0 || this.origH === 0) return 1
    return Math.min(this.side / this.origW, this.side / this.origH)
  }

  private dispW(): number {
    return this.origW * this.fitK() * this.zoomScale
  }

  private dispH(): number {
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
      // 方形编辑区。归一化完成前 loading；完成后显示转正 PixelMap
      // （宽高比与裁剪空间严格一致）。
      Column() {
        if (this.pixelMap === null || this.origW === 0 || this.origH === 0) {
          Column({ space: AppSpacing.x2 }) {
            LoadingProgress().width(36).height(36).color(AppColors.brand)
            Text('读取图片…').fontSize(12).fontColor(AppColors.textSecondary)
          }
          .width(this.side).height(this.side)
          .backgroundColor(AppColors.surfaceMuted)
          .borderRadius(AppRadii.card)
          .justifyContent(FlexAlign.Center)
        } else {
          Stack() {
            Image(this.pixelMap)
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
            // 圆形取景框：头像最终以圆形展示，圆内即最终效果（所见即所得）。
            Column()
              .width(this.side).height(this.side)
              .borderRadius(this.side / 2)
              .border({ width: 1.5, color: '#FFFFFFCC' })
              .hitTestBehavior(HitTestMode.Transparent)
          }
          .width(this.side).height(this.side)
          .backgroundColor('#000000')
          .borderRadius(AppRadii.card)
          .clip(true)
        }
      }
      // 首次布局拿实际方形边长（两个分支同尺寸，onAreaChange 放共用容器）。
      .onAreaChange((_old: Area, newArea: Area) => {
        const w = Number(newArea.width)
        if (w > 0 && Math.abs(w - this.side) > 0.5) {
          this.side = w
          this.zoomScale = 1
          this.offsetX = 0
          this.offsetY = 0
        }
      })

      Text('圆形内为最终效果 · 双指缩放 · 单指拖拽').fontSize(12).fontColor(AppColors.textSecondary)

      // sheet 内状态展示：全局 toast 会被 sheet 遮住（"点了没反应"的根因），
      // 上传中/失败状态必须画在 sheet 里。
      if (this.busy) {
        Row({ space: AppSpacing.x2 }) {
          LoadingProgress().width(18).height(18).color(AppColors.brand)
          Text('正在裁剪并上传…').fontSize(13).fontColor(AppColors.brand)
        }
      }
      if (this.error.length > 0) {
        Text(this.error).fontSize(13).fontColor(AppColors.error)
      }

      // AppButton 内部 width('100%')——必须各包 layoutWeight(1) 容器平分宽，
      // 否则取消按钮占满整行、确认按钮被挤出屏幕不可见。
      Row({ space: AppSpacing.x3 }) {
        Column() {
          AppButton({ label: '取消', onTap: () => this.onCancel() })
        }.layoutWeight(1)
        Column() {
          AppButton({
            label: this.busy ? '上传中…' : '确认上传',
            icon: AppIconName.Check,
            onTap: () => this.confirm()
          })
        }.layoutWeight(1)
      }.width('100%')
    }
    .width('100%')
    .padding(AppSpacing.x5)
  }

  private async confirm(): Promise<void> {
    if (this.busy || this.origW === 0 || this.normalized === null) return
    this.busy = true
    this.error = ''
    try {
      // 手势 → 转正空间方形区域。图左上角显示坐标 = 中心 - 半尺寸 + 偏移；
      // 反解除以总显示缩放（fitK × scale）。显示与裁剪同一空间，无映射。
      const k = this.fitK() * this.zoomScale
      const left = this.side / 2 - this.dispW() / 2 + this.offsetX
      const top = this.side / 2 - this.dispH() / 2 + this.offsetY
      let sideOrig = Math.min(this.side / k, Math.min(this.origW, this.origH))
      sideOrig = Math.max(1, Math.floor(sideOrig))
      let rx = Math.floor(-left / k)
      let ry = Math.floor(-top / k)
      rx = Math.max(0, Math.min(this.origW - sideOrig, rx))
      ry = Math.max(0, Math.min(this.origH - sideOrig, ry))

      const cropRegion: CropRegion = {
        x: rx, y: ry, width: sideOrig, height: sideOrig
      }
      const packed: ArrayBuffer =
        await cropToJpegBytes(this.normalized, cropRegion)

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
      // 非 Error 实例（部分原生错误）也要有可读信息，不再吞成统一文案。
      const detail = error instanceof Error
        ? error.message : `${error instanceof Object ? JSON.stringify(error) : String(error)}`
      const message = detail.length > 0 ? detail : '头像上传失败，请重试'
      // catch 分支错误必须进遥测（app_error），否则线上永远查不到。
      const props = new Map<string, TelemetryValue>()
      props.set('source', 'avatar_upload')
      telemetry.report(new Error(message), props)
      // sheet 内联展示（原生 toast 顶层弹，两处都保留）。
      this.error = message
      this.store.showToast(message, true)
    }
  }
}
