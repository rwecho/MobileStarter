import { AppRoute } from '../navigation/AppRoute'
import { AppStore } from '../state/AppStore'
import { AppButton } from '../design_system/Components'
import { AppColors, AppRadii, AppSpacing } from '../theme/AppTokens'

// ── Logo page ─────────────────────────────────────────────────────────
// Shows the shared brand logo while the app bootstraps, then auto‑navigates
// to the promo page after a minimum display time. No tap required.

@Component
export struct LogoPage {
  @ObjectLink store: AppStore
  private timer: number = -1

  aboutToAppear(): void {
    this.timer = setTimeout(() => {
      this.store.navigate(AppRoute.Promo)
    }, 1500)
  }

  aboutToDisappear(): void {
    if (this.timer !== -1) clearTimeout(this.timer)
  }

  build() {
    Column({ space: AppSpacing.x4 }) {
      Image($r('app.media.logo'))
        .width(48)
        .height(48)
      Text(this.store.config?.brand.appName ?? 'MobileUI')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
      Text('正在加载…')
        .fontColor(AppColors.textSecondary)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}

// ── Promo / campaign page ──────────────────────────────────────────────
// Displays the campaign artwork with a 3‑2‑1 countdown that auto‑enters
// the home screen when it reaches 0. A "跳过" button lets the user skip.

@Component
export struct PromoPage {
  @ObjectLink store: AppStore
  @State countdown: number = 3
  @State imageFailed: boolean = false
  private timer: number = -1
  private entered: boolean = false

  aboutToAppear(): void {
    this.timer = setInterval(() => {
      if (this.countdown <= 1) {
        clearInterval(this.timer)
        this.enter()
        return
      }
      this.countdown--
    }, 1000)
  }

  aboutToDisappear(): void {
    if (this.timer !== -1) clearInterval(this.timer)
  }

  enter(): void {
    if (this.entered) return
    this.entered = true
    this.store.replaceAll(AppRoute.Home)
  }

  build() {
    Column({ space: AppSpacing.x5 }) {
      Row() {
        Text(`${this.countdown}`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.brand)
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .backgroundColor(AppColors.brandSoft)
          .borderRadius(22)
          .accessibilityText(`倒计时 ${this.countdown}`)
        Blank()
        if (this.store.config?.splash.skippable !== false) {
          Button('跳过')
            .fontColor(AppColors.textSecondary)
            .backgroundColor(Color.Transparent)
            .height(44)
            .padding({ left: AppSpacing.x3, right: AppSpacing.x3 })
            .onClick(() => {
              clearInterval(this.timer)
              this.enter()
            })
        }
      }
      .width('100%')
      .height(44)
      Blank()
      if (this.store.config?.splash.imageUrl && !this.imageFailed) {
        Image(this.store.config.splash.imageUrl)
          .alt($r('app.media.promo'))
          .width('100%')
          .height(220)
          .objectFit(ImageFit.Contain)
          .onError(() => { this.imageFailed = true })
      } else {
        Image($r('app.media.promo'))
          .width('100%')
          .height(220)
          .objectFit(ImageFit.Contain)
      }
      Text(this.store.config?.splash.title ?? '让每次使用都更简单')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
      Text(this.store.config?.splash.description ??
        '这里可以由远程配置展示活动、广告或新功能。')
        .fontColor(AppColors.textSecondary)
      Blank()
    }
    .padding(AppSpacing.x6)
    .width('100%')
    .height('100%')
  }
}

// ── Onboarding (unchanged) ────────────────────────────────────────────

@Component
export struct OnboardingPage {
  @ObjectLink store: AppStore

  build() {
    Column({ space: AppSpacing.x5 }) {
      Image($r('app.media.promo'))
        .width('100%')
        .height(220)
        .objectFit(ImageFit.Contain)
      Text('三步了解核心功能').fontSize(28).fontWeight(FontWeight.Bold)
      Text('首次安装展示，完成后不会重复出现。')
        .fontColor(AppColors.textSecondary)
      AppButton({
        label: '完成引导',
        onTap: () => this.store.replaceAll(AppRoute.Home)
      })
    }
    .padding(AppSpacing.x6)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
