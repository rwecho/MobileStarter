export type TelemetryValue = string | number | boolean

export type TelemetryProperties = Map<string, TelemetryValue>

export interface TelemetryEvent {
  eventId: string
  name: string
  screenId: string
  occurredAt: string
  configVersion: number
  properties: TelemetryProperties
}

export interface TelemetryBatch {
  anonymousId: string
  sessionId: string
  events: TelemetryEvent[]
}

export interface TelemetrySink {
  send(batch: TelemetryBatch): Promise<boolean>
}

export class TelemetryConfig {
  enabled: boolean = true
  backendEnabled: boolean = true
  configVersion: number = 0
}

class Telemetry {
  private readonly maxQueue: number = 200
  private readonly batchSize: number = 25
  private readonly sessionId: string = this.createId('session')
  private readonly anonymousId: string = this.createId('anonymous')
  private config: TelemetryConfig = new TelemetryConfig()
  private queue: TelemetryEvent[] = []
  private sink: TelemetrySink | null = null
  private currentScreen: string = ''
  private screenStartedAt: number = Date.now()
  private flushing: boolean = false
  private flushScheduled: boolean = false
  private retryIndex: number = 0
  // 磁盘快照（§3.1，对齐 RN 端）：enqueue 防抖落盘、启动恢复。进程被杀
  // （崩溃/OOM）时内存队列丢失，快照保证下次启动补发（issue #22）。
  private saveQueue: ((json: string) => void) | null = null
  private persistScheduled: boolean = false

  // 恢复快照必须在 configure() 之前调用（AppStore.initialize 里注入）。
  setPersistence(load: () => string | null, save: (json: string) => void): void {
    this.saveQueue = save
    const saved = load()
    if (saved !== null && saved.length > 0) {
      this.restoreFromJson(saved)
    }
  }

  // 崩溃 watcher 立即落盘（进程可能马上死，不等防抖）。
  persistNow(): void {
    this.persistScheduled = false
    if (this.saveQueue !== null) {
      this.saveQueue(this.serializeQueue())
    }
  }

  private schedulePersist(): void {
    if (this.saveQueue === null || this.persistScheduled) {
      return
    }
    this.persistScheduled = true
    setTimeout(() => {
      this.persistScheduled = false
      this.persistNow()
    }, 300)
  }

  private serializeQueue(): string {
    const items: object[] = []
    for (const event of this.queue) {
      const props: string[][] = []
      event.properties.forEach((value: TelemetryValue, key: string) => {
        props.push([key, `${value}`])
      })
      const item: Record<string, Object> = {
        'eventId': event.eventId,
        'name': event.name,
        'screenId': event.screenId,
        'occurredAt': event.occurredAt,
        'configVersion': event.configVersion,
        'properties': props
      }
      items.push(item)
    }
    return JSON.stringify({ 'anonymousId': this.anonymousId, 'events': items })
  }

  private restoreFromJson(saved: string): void {
    try {
      const parsed = JSON.parse(saved) as Record<string, Object>
      const events = parsed['events'] as object[] | undefined
      if (events === undefined) return
      for (const raw of events) {
        const item = raw as Record<string, Object>
        const propsRaw = item['properties'] as string[][] | undefined
        const properties = new Map<string, TelemetryValue>()
        if (propsRaw !== undefined) {
          for (const pair of propsRaw) {
            if (pair.length >= 2) {
              properties.set(pair[0], pair[1])
            }
          }
        }
        const event: TelemetryEvent = {
          eventId: `${item['eventId']}`,
          name: `${item['name']}`,
          screenId: `${item['screenId']}`,
          occurredAt: `${item['occurredAt']}`,
          configVersion: Number(item['configVersion']),
          properties: properties
        }
        this.queue.push(event)
      }
      while (this.queue.length > this.maxQueue) {
        this.queue.shift()
      }
    } catch (_) {
      // 损坏的快照直接丢弃，不影响启动。
    }
  }

  configure(config: TelemetryConfig, sink: TelemetrySink | null): void {
    this.config = config
    this.sink = sink
    this.scheduleFlush(0)
  }

  screen(screenId: string): void {
    if (this.currentScreen === screenId) {
      return
    }
    if (this.currentScreen.length > 0) {
      const leaveProperties = new Map<string, TelemetryValue>()
      leaveProperties.set('screen_id', this.currentScreen)
      leaveProperties.set('duration_ms', Date.now() - this.screenStartedAt)
      this.track('screen_leave', leaveProperties, this.currentScreen)
    }
    this.currentScreen = screenId
    this.screenStartedAt = Date.now()
    const properties = new Map<string, TelemetryValue>()
    properties.set('screen_id', screenId)
    this.track('screen_view', properties, screenId)
  }

  track(
    name: string,
    properties: TelemetryProperties = new Map<string, TelemetryValue>(),
    screenId: string = this.currentScreen
  ): void {
    if (!this.config.enabled || !this.config.backendEnabled) {
      return
    }
    if (this.queue.length >= this.maxQueue) {
      this.queue.shift()
    }
    this.queue.push({
      eventId: this.createId('evt'),
      name: name,
      screenId: screenId,
      occurredAt: new Date().toISOString(),
      configVersion: this.config.configVersion,
      properties: properties
    })
    this.schedulePersist()
    this.scheduleFlush(2000)
  }

  report(error: Error, context: TelemetryProperties = new Map<string, TelemetryValue>()): void {
    const properties = new Map<string, TelemetryValue>(context)
    properties.set('error_name', error.name)
    properties.set('error_message', error.message.substring(0, 180))
    this.track('app_error', properties)
  }

  private scheduleFlush(delayMs: number): void {
    if (this.flushing || this.flushScheduled || this.queue.length === 0) {
      return
    }
    this.flushScheduled = true
    setTimeout(() => {
      this.flushScheduled = false
      this.flush()
    }, delayMs)
  }

  private async flush(): Promise<void> {
    if (this.flushing || this.queue.length === 0 || this.sink === null) {
      return
    }
    this.flushing = true
    const events = this.queue.slice(0, this.batchSize)
    try {
      const accepted = await this.withTimeout(this.sink.send({
        anonymousId: this.anonymousId,
        sessionId: this.sessionId,
        events: events
      }), 5000)
      if (!accepted) {
        throw new Error('Telemetry rejected')
      }
      this.queue = this.queue.slice(events.length)
      this.retryIndex = 0
      this.schedulePersist()
    } catch (_) {
      this.retryIndex = Math.min(this.retryIndex + 1, 4)
    } finally {
      this.flushing = false
      if (this.queue.length > 0) {
        const delays: number[] = [2000, 5000, 15000, 30000, 60000]
        this.scheduleFlush(delays[this.retryIndex])
      }
    }
  }

  private withTimeout(operation: Promise<boolean>, delayMs: number): Promise<boolean> {
    return Promise.race([
      operation,
      new Promise<boolean>((_, reject) => {
        setTimeout(() => reject(new Error('Telemetry timeout')), delayMs)
      })
    ])
  }

  private createId(prefix: string): string {
    return `${prefix}-${Date.now()}-${Math.floor(Math.random() * 1000000000)}`
  }
}

export const telemetry: Telemetry = new Telemetry()
