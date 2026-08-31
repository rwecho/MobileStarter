// 反馈/工单域模型——从 Models.ets 拆出以服从 CI 350 行硬上限。

export interface ProductFeedback {
  id: string
  category: string
  title: string
  body: string
  rating: number | null
  status: string
  market: string
  dataRegion: string
  queueId: string
  createdAt: string
  updatedAt: string
}

export interface FeedbackInput {
  category: string
  title: string
  body: string
  rating: number
}

export interface CreateTicketInput {
  category: string
  severity: string
  subject: string
  message: string
}
