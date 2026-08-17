import { UIAbility, Want } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { AbilityConstant, errorManager } from '@kit.AbilityKit'
import { hiAppEvent } from '@kit.PerformanceAnalysisKit'
import { EntryIntent, entryIntentInbox, routeNameFromWant } from '../navigation/EntryIntent'
import { telemetry, TelemetryValue } from '../telemetry/Telemetry'

// 崩溃/异常采集（issue #22，对齐 RN/Flutter 的 §1）：
//  1. globalErrorOccurred：ArkTS/JS 层未捕获异常 → telemetry.report。
//  2. hiAppEvent watcher：系统 fault（APP_CRASH 覆盖 cpp/js crash、APP_FREEZE）。
//     这类 fault 发生时进程往往已死，事件在下次启动派发到 onTrigger；
//     入队后 persistNow() 立即落盘，磁盘快照保证补发不丢。
function installCrashTelemetry(): void {
  errorManager.on('globalErrorOccurred', (error) => {
    telemetry.report(new Error(`uncaught: ${error.message ?? 'unknown'}`))
    telemetry.persistNow()
  })
  try {
    hiAppEvent.addWatcher({
      name: 'msfaults1',
      appEventFilters: [
        {
          domain: hiAppEvent.domain.OS,
          names: [hiAppEvent.event.APP_CRASH, hiAppEvent.event.APP_FREEZE]
        }
      ],
      onTrigger: (_curRow: number, _curSize: number,
        holder: hiAppEvent.AppEventPackageHolder) => {
        // takeNext 逐包取；固定上限防御异常循环。
        for (let i = 0; i < 20; i++) {
          const pack: hiAppEvent.AppEventPackage = holder.takeNext()
          const infos: hiAppEvent.AppEventInfo[] = pack?.appEventInfos ?? []
          if (infos.length === 0) {
            break
          }
          for (const info of infos) {
            const props = new Map<string, TelemetryValue>()
            props.set('fault_domain', info.domain)
            props.set('fault_name', info.name)
            props.set('fault_event_type', `${info.eventType}`)
            telemetry.track('native_crash', props)
          }
          telemetry.persistNow()
        }
      }
    })
  } catch (_) {
    // hiAppEvent 不可用（部分模拟器）不阻塞启动。
  }
}

export default class EntryAbility extends UIAbility {
  private enteredForeground: boolean = false

  onCreate(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    installCrashTelemetry()
    entryIntentInbox.publish(new EntryIntent(routeNameFromWant(want), true))
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index')
  }

  onNewWant(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    entryIntentInbox.publish(new EntryIntent(routeNameFromWant(want), false))
  }

  onForeground(): void {
    if (this.enteredForeground) entryIntentInbox.publishResume()
    this.enteredForeground = true
  }
}
