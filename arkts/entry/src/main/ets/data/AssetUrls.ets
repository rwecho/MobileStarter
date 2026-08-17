import { apiClient } from './ApiClient'

// 通用资产 objectKey → presigned URL（私有 bucket，24h 有效）。
// 适用于一切对象（avatar/视频/音频/文档…），会话级缓存避免重复请求；
// 加载失败（过期）调 invalidateAssetUrl 清掉，下次重新换取。
// ArkTS 无 delete：缓存槽置空串（undefined 保留 key，语义等价失效）。

const urlCache: Record<string, string> = {}
const inflight: Record<string, Promise<string | null> | string> = {}

export async function resolveAssetUrl(objectKey: string): Promise<string | null> {
  const cached = urlCache[objectKey]
  if (cached !== undefined && cached.length > 0) return cached
  // 同 key 并发请求合并为一次（ArkTS 无 delete：完成后置空串即失效）。
  const pending = inflight[objectKey]
  if (pending !== undefined && pending !== null) return pending
  const task = apiClient.resolveObjectUrl(objectKey).then((url: string | null): string | null => {
    inflight[objectKey] = ''
    if (url !== null) urlCache[objectKey] = url
    return url
  })
  inflight[objectKey] = task
  return task
}

export function invalidateAssetUrl(objectKey: string): void {
  urlCache[objectKey] = ''
}
