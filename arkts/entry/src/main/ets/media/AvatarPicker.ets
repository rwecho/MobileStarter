import photoAccessHelper from '@ohos.file.photoAccessHelper'
import image from '@ohos.multimedia.image'
import fs from '@ohos.file.fs'
import buffer from '@ohos.buffer'
import common from '@ohos.app.ability.common'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'AvatarPicker'
const DOMAIN = 0xC0DE

// PhotoViewPicker 返回的是媒体库 uri（file://media/...，临时只读授权），
// createImageSource 只认应用沙箱路径——必须先 fs.openSync 拿 fd 再创建，
// 用完关闭。封装成统一工具，头像/截图等复用（issue #21）。
interface ImageSourceHandle {
  source: image.ImageSource
  file: fs.File
}

export interface CropRegion {
  x: number
  y: number
  width: number
  height: number
}

export interface ImageSize {
  width: number
  height: number
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

// 读取原图尺寸（编辑器的手势换算需要）。
export async function readImageSize(uri: string): Promise<ImageSize> {
  const handle = openImageSource(uri)
  try {
    const info = await handle.source.getImageInfo()
    const size: ImageSize = { width: info.size.width, height: info.size.height }
    return size
  } finally {
    closeImageSource(handle)
  }
}

// 按原图坐标裁剪方形区域 → 512×512 JPEG bytes（AvatarEditor 确认时调用）。
export async function cropToJpegBytes(uri: string, region: CropRegion): Promise<ArrayBuffer> {
  const handle = openImageSource(uri)
  try {
    const size: image.Size = { width: region.width, height: region.height }
    const cropRegion: image.Region = { x: region.x, y: region.y, size }
    const pixelMap = await handle.source.createPixelMap({
      desiredRegion: cropRegion,
      desiredSize: { width: 512, height: 512 }
    })
    const packer = image.createImagePacker()
    try {
      return await packer.packToData(pixelMap, { format: 'image/jpeg', quality: 80 })
    } finally {
      packer.release()
      pixelMap.release()
    }
  } finally {
    closeImageSource(handle)
  }
}

// 兼容旧路径：选图 → 中心方形 512×512 → base64 data URL（avatar 已改走
// 对象存储，保留给反馈截图等未迁移场景）。失败时 hilog 记录再抛出。
export async function pickAvatarDataUrl(context: common.UIAbilityContext): Promise<string | null> {
  const uri = await pickAvatarUri()
  if (uri === null) return null
  try {
    const size = await readImageSize(uri)
    const side = Math.min(size.width, size.height)
    const centerRegion: CropRegion = {
      x: Math.floor((size.width - side) / 2),
      y: Math.floor((size.height - side) / 2),
      width: side,
      height: side
    }
    const bytes = await cropToJpegBytes(uri, centerRegion)
    const base64 = buffer.from(bytes).toString('base64')
    return `data:image/jpeg;base64,${base64}`
  } catch (error) {
    hilog.error(DOMAIN, TAG, 'pickAvatarDataUrl failed: %{public}s', `${error}`)
    throw error instanceof Error ? error : new Error(`${error}`)
  }
}
