import { UIAbility, Want } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { AbilityConstant } from '@kit.AbilityKit'

export default class EntryAbility extends UIAbility {
  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index')
  }
}
