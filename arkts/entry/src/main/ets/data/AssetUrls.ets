import { apiClient } from './ApiClient'

// 通用资产 objectKey → presigned URL（私有 bucket，24h 有效）。
// 适用于一切对象（avatar/视频/音频/文档…），会话级缓存避免重复请求；
// 加载失败（过期）调 invalidateAssetUrl 清掉，下次重新换取。
// ArkTS 无 delete：缓存槽置空串（undefined 保留 key，语义等价失效）。

const urlCache: Record<string, string> = {}
const inflight: Record<string, Promise<string | null> | string> = {}

export async function resolveAssetUrl(rawValue: string): Promise<string | null> {
  // 历史脏数据兼容：旧版本客户端把 opaque `s3://bucket/key` 直接存进了
  // avatarUrl，剥掉 scheme 与 bucket 段还原 objectKey 再换取。
  let objectKey = rawValue
  if (objectKey.startsWith('s3://')) {
    objectKey = objectKey.substring(5)
    const slash = objectKey.indexOf('/')
    if (slash > 0) objectKey = objectKey.substring(slash + 1)
  }
  const cached = urlCache[rawValue]
  if (cached !== undefined && cached.length > 0) return cached
  // 同 key 并发请求合并为一次（ArkTS 无 delete：完成后置空串即失效）。
  const pending = inflight[rawValue]
  if (pending !== undefined && pending !== null) return pending
  const task = apiClient.resolveObjectUrl(objectKey).then((url: string | null): string | null => {
    inflight[rawValue] = ''
    if (url !== null) urlCache[rawValue] = url
    return url
  })
  inflight[rawValue] = task
  return task
}

export function invalidateAssetUrl(objectKey: string): void {
  urlCache[objectKey] = ''
}
