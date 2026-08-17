import photoAccessHelper from '@ohos.file.photoAccessHelper'
import image from '@ohos.multimedia.image'
import fs from '@ohos.file.fs'
import buffer from '@ohos.buffer'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'AvatarPicker'
const DOMAIN = 0xC0DE

// PhotoViewPicker 返回的是媒体库 uri（file://media/...，临时只读授权），
// createImageSource 只认应用沙箱路径——必须先 fs.openSync 拿 fd 再创建，
// 用完关闭。封装成统一工具，头像/截图等复用（issue #21）。
//
// EXIF 方向（issue：头像变形）：手机照片多带 Orientation（6=90°CW、8=270°CW）。
// Image 组件显示时会自动转正，但 getImageInfo 拿到的是未旋转像素尺寸，
// 两者不一致 → 宽高颠倒 → Fill 拉伸变形。本模块统一在「显示空间」工作：
// meta.width/height 已按 EXIF 交换；裁剪时反向映射回原图像素空间并在
// packer 前用 PixelMap.rotate 转回用户所见方向。
export interface ImageSourceHandle {
  source: image.ImageSource
  file: fs.File
}

export interface CropRegion {
  x: number
  y: number
  width: number
  height: number
}

// 显示空间元数据：width/height 为 EXIF 转正后的尺寸；orientation 1..8。
export interface ImageMeta {
  width: number
  height: number
  orientation: number
  origWidth: number
  origHeight: number
}

function openImageSource(uri: string): ImageSourceHandle {
  const file = fs.openSync(uri, fs.OpenMode.READ_ONLY)
  const source = image.createImageSource(file.fd)
  const handle: ImageSourceHandle = { source, file }
  return handle
}

function closeImageSource(handle: ImageSourceHandle): void {
  handle.source.release()
  fs.closeSync(handle.file)
}

const ORIENTATION_NAMES: Record<string, number> = {
  'Top-left': 1, 'Top-right': 2, 'Bottom-right': 3, 'Bottom-left': 4,
  'Left-top': 5, 'Right-top': 6, 'Right-bottom': 7, 'Left-bottom': 8
}

function parseOrientation(raw: string): number {
  const named = ORIENTATION_NAMES[raw]
  if (named !== undefined) return named
  const n = Number(raw)
  return n >= 1 && n <= 8 ? n : 1
}

// 是否 90/270（宽高颠倒）。
function isSwapped(orientation: number): boolean {
  return orientation === 5 || orientation === 6 || orientation === 7 || orientation === 8
}

// 选图（媒体库），返回原始 uri 供 AvatarEditor 编辑。
export async function pickAvatarUri(): Promise<string | null> {
  const options = new photoAccessHelper.PhotoSelectOptions()
  options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
  options.maxSelectNumber = 1
  const picker = new photoAccessHelper.PhotoViewPicker()
  const selection = await picker.select(options)
  if (selection.photoUris.length === 0) return null
  return selection.photoUris[0]
}

// 读取元数据（显示空间尺寸 + EXIF orientation + 原始像素尺寸）。
export async function readImageMeta(uri: string): Promise<ImageMeta> {
  const handle = openImageSource(uri)
  try {
    const info = await handle.source.getImageInfo()
    let orientation = 1
    try {
      const raw = await handle.source.getImageProperty('Orientation')
      orientation = parseOrientation(String(raw))
    } catch (_) {
      orientation = 1
    }
    const meta: ImageMeta = {
      width: isSwapped(orientation) ? info.size.height : info.size.width,
      height: isSwapped(orientation) ? info.size.width : info.size.height,
      orientation,
      origWidth: info.size.width,
      origHeight: info.size.height
    }
    return meta
  } finally {
    closeImageSource(handle)
  }
}

// 显示空间方形区域 → 512×512 JPEG bytes。内部反向映射回原图像素空间，
// 解码后按 EXIF 旋转回用户所见方向再编码（输出无 EXIF，方向即内容）。
export async function cropToJpegBytes(uri: string, region: CropRegion, meta: ImageMeta):
  Promise<ArrayBuffer> {
  const handle = openImageSource(uri)
  try {
    // 显示空间 (dx,dy) → 原图空间 (ox,oy) 的方形映射（仅处理 90/180/270，
    // 镜像 2/4/5/7 罕见于相册照片，按未旋转处理）。
    let x = region.x
    let y = region.y
    let rotateDeg = 0
    const s = region.width
    if (meta.orientation === 6) {
      // 90°CW：显示 = 原图顺转90。原图 (ox,oy) → 显示 (origH-1-oy, ox)
      // 显示方形 [rx,ry,s] → 原图 [x=ry, y=origH-rx-s]
      x = region.y
      y = meta.origHeight - region.x - s
      rotateDeg = 90
    } else if (meta.orientation === 8) {
      // 270°CW：原图 (ox,oy) → 显示 (oy, origW-1-ox)
      x = meta.origWidth - region.y - s
      y = region.x
      rotateDeg = 270
    } else if (meta.orientation === 3) {
      x = meta.origWidth - region.x - s
      y = meta.origHeight - region.y - s
      rotateDeg = 180
    }
    x = Math.max(0, Math.min(Math.floor(x), Math.max(0, meta.origWidth - s)))
    y = Math.max(0, Math.min(Math.floor(y), Math.max(0, meta.origHeight - s)))

    const size: image.Size = { width: s, height: s }
    const cropRegion: image.Region = { x, y, size }
    const pixelMap = await handle.source.createPixelMap({
      desiredRegion: cropRegion,
      desiredSize: { width: 512, height: 512 }
    })
    try {
      if (rotateDeg > 0) {
        await pixelMap.rotate(rotateDeg)
      }
      const packer = image.createImagePacker()
      try {
        return await packer.packToData(pixelMap, { format: 'image/jpeg', quality: 80 })
      } finally {
        packer.release()
      }
    } finally {
      pixelMap.release()
    }
  } finally {
    closeImageSource(handle)
  }
}

// 兼容旧路径：选图 → 中心方形 512×512 → base64 data URL（avatar 已改走
// 对象存储，保留给反馈截图等未迁移场景）。失败时 hilog 记录再抛出。
export async function pickAvatarDataUrl(context: Context): Promise<string | null> {
  const uri = await pickAvatarUri()
  if (uri === null) return null
  try {
    const meta = await readImageMeta(uri)
    const side = Math.min(meta.width, meta.height)
    const centerRegion: CropRegion = {
      x: Math.floor((meta.width - side) / 2),
      y: Math.floor((meta.height - side) / 2),
      width: side,
      height: side
    }
    const bytes = await cropToJpegBytes(uri, centerRegion, meta)
    const base64 = buffer.from(bytes).toString('base64')
    return `data:image/jpeg;base64,${base64}`
  } catch (error) {
    hilog.error(DOMAIN, TAG, 'pickAvatarDataUrl failed: %{public}s', `${error}`)
    throw error instanceof Error ? error : new Error(`${error}`)
  }
}
