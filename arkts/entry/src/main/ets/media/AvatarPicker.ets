import photoAccessHelper from '@ohos.file.photoAccessHelper'
import image from '@ohos.multimedia.image'
import fs from '@ohos.file.fs'
import buffer from '@ohos.buffer'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'AvatarPicker'
const DOMAIN = 0xC0DE

// ── 归一化管线（根治编辑器变形）──────────────────────────────────────────────
// 媒体库 uri（file://media/...）直接交给 Image 组件时，其解码/EXIF 行为与
// 我们 fd 解码的空间不一定一致（Image 会自动转正，getImageInfo 不会），
// 宽高比颠倒 → 拉伸变形。因此进编辑器前先归一化：
//   fd 打开 → 全图解码 → 按 EXIF rotate 转正 →
//   产出显示用 PixelMap + 裁剪用 JPEG bytes（同一转正空间）
// 显示（Image(pixelMap)）与裁剪（createImageSource(bytes).desiredRegion）
// 共享同一空间，不存在任何映射/方向歧义。
export interface CropRegion {
  x: number
  y: number
  width: number
  height: number
}

export interface NormalizedImage {
  pixelMap: image.PixelMap
  bytes: ArrayBuffer
  width: number
  height: number
}

interface ImageSourceHandle {
  source: image.ImageSource
  file: fs.File
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

function rotationFor(orientation: number): number {
  if (orientation === 6) return 90
  if (orientation === 8) return 270
  if (orientation === 3) return 180
  return 0
}

// 选图（媒体库），返回原始 uri 供 AvatarEditor 归一化。
export async function pickAvatarUri(): Promise<string | null> {
  const options = new photoAccessHelper.PhotoSelectOptions()
  options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
  options.maxSelectNumber = 1
  const picker = new photoAccessHelper.PhotoViewPicker()
  const selection = await picker.select(options)
  if (selection.photoUris.length === 0) return null
  return selection.photoUris[0]
}

// 归一化：EXIF 转正的 PixelMap（显示）+ 同空间 JPEG bytes（裁剪源）。
export async function loadNormalizedImage(uri: string): Promise<NormalizedImage> {
  const handle = openImageSource(uri)
  let orientation = 1
  try {
    const raw = await handle.source.getImageProperty('Orientation')
    orientation = parseOrientation(String(raw))
  } catch (_) {
    orientation = 1
  }
  // 全图解码（原尺寸；头像场景大图一次性内存可接受，用完即释放）。
  const pixelMap = await handle.source.createPixelMap()
  closeImageSource(handle)
  try {
    const deg = rotationFor(orientation)
    if (deg > 0) {
      await pixelMap.rotate(deg)
    }
    // 转正后重编码：既作裁剪源，也顺带抹掉 EXIF（输出方向即内容）。
    let packer = image.createImagePacker()
    let bytes: ArrayBuffer
    try {
      bytes = await packer.packToData(pixelMap, { format: 'image/jpeg', quality: 90 })
    } finally {
      packer.release()
    }
    const info = await pixelMap.getImageInfo()
    const result: NormalizedImage = {
      pixelMap: pixelMap,
      bytes: bytes,
      width: info.size.width,
      height: info.size.height
    }
    return result
  } catch (error) {
    pixelMap.release()
    throw error instanceof Error ? error : new Error(`${error}`)
  }
}

// 转正空间方形区域 → 512×512 JPEG bytes（AvatarEditor 确认时调用）。
// 不用 createPixelMap({desiredRegion, desiredSize})——该组合在小 region
// （缩放后）触发解码器 "unsupport options"（pixelformat/crop failed）。
// 改为：全图解码 → PixelMap.crop(region) → PixelMap.scale(512) → 编码。
// 每次新解码独立副本，可安全重试（不破坏显示用 PixelMap）。
export async function cropToJpegBytes(img: NormalizedImage, region: CropRegion):
  Promise<ArrayBuffer> {
  const x = Math.max(0, Math.min(Math.floor(region.x), Math.max(0, img.width - region.width)))
  const y = Math.max(0, Math.min(Math.floor(region.y), Math.max(0, img.height - region.height)))
  const size: image.Size = { width: region.width, height: region.height }
  const cropRegion: image.Region = { x, y, size }
  const source = image.createImageSource(img.bytes)
  try {
    const pixelMap = await source.createPixelMap()
    try {
      await pixelMap.crop(cropRegion)
      const ratio = 512 / region.width
      await pixelMap.scale(ratio, ratio)
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
    source.release()
  }
}

// 兼容旧路径：选图 → 中心方形 512×512 → base64 data URL（avatar 已改走
// 对象存储，保留给反馈截图等未迁移场景）。失败时 hilog 记录再抛出。
export async function pickAvatarDataUrl(context: Context): Promise<string | null> {
  const uri = await pickAvatarUri()
  if (uri === null) return null
  try {
    const normalized = await loadNormalizedImage(uri)
    try {
      const side = Math.min(normalized.width, normalized.height)
      const centerRegion: CropRegion = {
        x: Math.floor((normalized.width - side) / 2),
        y: Math.floor((normalized.height - side) / 2),
        width: side,
        height: side
      }
      const bytes = await cropToJpegBytes(normalized, centerRegion)
      const base64 = buffer.from(bytes).toString('base64')
      return `data:image/jpeg;base64,${base64}`
    } finally {
      normalized.pixelMap.release()
    }
  } catch (error) {
    hilog.error(DOMAIN, TAG, 'pickAvatarDataUrl failed: %{public}s', `${error}`)
    throw error instanceof Error ? error : new Error(`${error}`)
  }
}
