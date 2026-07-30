import photoAccessHelper from '@ohos.multimedia.photoAccessHelper'
import image from '@ohos.multimedia.image'
import buffer from '@ohos.buffer'
import common from '@ohos.app.ability.common'

// Picks an image from the gallery, scales it to ~512px and returns a JPEG data
// URL persisted via updateProfile (no separate upload endpoint, like RN).
// Native APIs must be verified on a HarmonyOS device/simulator.
export async function pickAvatarDataUrl(context: common.UIAbilityContext): Promise<string | null> {
  try {
    const helper = photoAccessHelper.getPhotoAccessHelper(context)
    const selection = await helper.openPicker({
      filterSelectionOptions: {
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE,
        maxSelectNumber: 1
      }
    })
    const uri = selection.photoUris[0]
    if (uri === undefined) return null
    const source = image.createImageSource(uri)
    const pixelMap = await source.createPixelMap({
      desiredSize: { width: 512, height: 512 }
    })
    const packer = image.createImagePacker()
    const packed: ArrayBuffer = await packer.packing(pixelMap, {
      format: 'image/jpeg',
      quality: 78
    })
    packer.release()
    pixelMap.release()
    source.release()
    const base64 = buffer.from(packed).toString('base64')
    return `data:image/jpeg;base64,${base64}`
  } catch (error) {
    return null
  }
}
