// 对象存储与客服支持端点——从 ApiClient.ets 拆出以服从 CI 350 行硬上限。
// ArkTS 无 partial class / extension，端点实现为收 transport 的自由函数，
// ApiClient 以薄委托保持原有调用面不变。
import http from '@ohos.net.http'
import { ApiTransport } from './ApiTransport'
import {
  HelpArticle,
  SignUploadResult,
  SupportMessage,
  SupportTicket,
  SupportTicketDetail
} from '../domain/Models'
import { CreateTicketInput, FeedbackInput } from '../domain/SupportModels'

// ── S3 storage (BaaS) ─────────────────────────────────────────────────────
// 申请上传：server 用 app_id + environment 选 bucket/key，返回 presigned PUT URL。
export function signUpload(
  transport: ApiTransport, path: string, contentType: string
): Promise<SignUploadResult> {
  return transport.request<SignUploadResult>(
    '/api/v1/storage/uploads', http.RequestMethod.POST, { path, contentType }
  )
}

// objectKey → 短时效 presigned GET URL（私有 bucket；每次显示前换取）。
// 返回 null 表示对象不存在/无权（调用方回退占位头像）。
export async function resolveObjectUrl(
  transport: ApiTransport, objectKey: string
): Promise<string | null> {
  try {
    const result = await transport.request<Record<string, string>>(
      `/api/v1/storage/urls?key=${encodeURIComponent(objectKey)}`,
      http.RequestMethod.GET
    )
    return result['url'] ?? null
  } catch {
    return null
  }
}

// ── 客服支持 ──────────────────────────────────────────────────────────────
export function submitFeedback(
  transport: ApiTransport,
  title: string,
  body: string,
  category: string = 'suggestion',
  rating: number = 5
): Promise<boolean> {
  const input: FeedbackInput = { category, title, body, rating }
  return transport.request<Record<string, string | number>>(
    '/api/v1/support/feedback',
    http.RequestMethod.POST,
    input
  ).then(result => String(result['id'] ?? '').length > 0)
}

export function help(transport: ApiTransport): Promise<HelpArticle[]> {
  return transport.request<HelpArticle[]>('/api/v1/support/help', http.RequestMethod.GET)
}

export function tickets(transport: ApiTransport): Promise<SupportTicket[]> {
  return transport.request<SupportTicket[]>('/api/v1/support/tickets', http.RequestMethod.GET)
}

export function ticket(transport: ApiTransport, id: string): Promise<SupportTicketDetail> {
  return transport.request<SupportTicketDetail>(
    `/api/v1/support/tickets/${id}`, http.RequestMethod.GET
  )
}

export function createTicket(
  transport: ApiTransport, input: CreateTicketInput
): Promise<SupportTicket> {
  return transport.request<SupportTicket>(
    '/api/v1/support/tickets', http.RequestMethod.POST, input
  )
}

export function reply(
  transport: ApiTransport, ticketId: string, message: string
): Promise<SupportMessage> {
  return transport.request<SupportMessage>(
    `/api/v1/support/tickets/${ticketId}/messages`,
    http.RequestMethod.POST,
    { message }
  )
}
