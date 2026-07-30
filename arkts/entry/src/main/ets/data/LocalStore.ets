import common from '@ohos.app.ability.common'
import preferences from '@ohos.data.preferences'
import { RuntimeConfig } from '../domain/Models'

const STORE_NAME: string = 'mobileui.runtime'
const TOKEN_KEY: string = 'sessionToken'
const REFRESH_TOKEN_KEY: string = 'sessionRefreshToken'
const CONFIG_KEY: string = 'runtimeConfig'
const INSTALLATION_KEY: string = 'installationId'

export class LocalStore {
  private store?: preferences.Preferences

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.store = await preferences.getPreferences(context, STORE_NAME)
  }

  readToken(): string {
    return String(this.store?.getSync(TOKEN_KEY, '') ?? '')
  }

  saveToken(token: string): void {
    this.store?.putSync(TOKEN_KEY, token)
    this.store?.flush()
  }

  readRefreshToken(): string {
    return String(this.store?.getSync(REFRESH_TOKEN_KEY, '') ?? '')
  }

  saveRefreshToken(token: string): void {
    this.store?.putSync(REFRESH_TOKEN_KEY, token)
    this.store?.flush()
  }

  readConfig(): RuntimeConfig | null {
    const value = String(this.store?.getSync(CONFIG_KEY, '') ?? '')
    if (value.length === 0) {
      return null
    }
    try {
      return JSON.parse(value) as RuntimeConfig
    } catch (error) {
      return null
    }
  }

  saveConfig(config: RuntimeConfig): void {
    this.store?.putSync(CONFIG_KEY, JSON.stringify(config))
    this.store?.flush()
  }

  installationId(): string {
    const existing = String(this.store?.getSync(INSTALLATION_KEY, '') ?? '')
    if (existing.length >= 8) return existing
    const value = `harmony-${Date.now()}-${Math.floor(Math.random() * 1000000)}`
    this.store?.putSync(INSTALLATION_KEY, value)
    this.store?.flush()
    return value
  }

  configBytes(): number {
    return String(this.store?.getSync(CONFIG_KEY, '') ?? '').length
  }

  clearRuntimeCache(): void {
    this.store?.deleteSync(CONFIG_KEY)
    this.store?.flush()
  }
}

export const localStore: LocalStore = new LocalStore()
