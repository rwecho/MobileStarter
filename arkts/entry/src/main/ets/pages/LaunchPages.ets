import { AppRoute } from '../navigation/AppRoute'
import { AppStore } from '../state/AppStore'
import { AppButton } from '../design_system/Components'
import { AppColors, AppRadii, AppSpacing } from '../theme/AppTokens'

@Component
export struct LogoPage {
  @ObjectLink store: AppStore

  build() {
    Column({ space: AppSpacing.x4 }) {
      Stack() {
        Rect()
          .width(72)
          .height(72)
          .radius(AppRadii.card)
          .fill(AppColors.brand)
        Rect()
          .width(30)
          .height(30)
          .radius(AppRadii.small)
          .fill(AppColors.surface)
          .rotate({ angle: 45 })
      }
      Text(this.store.config?.brand.appName ?? 'MobileUI')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
      Text('轻触继续').fontColor(AppColors.textSecondary)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => this.store.navigate(AppRoute.Promo))
  }
}

@Component
export struct PromoPage {
  @ObjectLink store: AppStore
  @State imageFailed: boolean = false

  build() {
    Column({ space: AppSpacing.x5 }) {
      Text('跳过')
        .fontColor(AppColors.textSecondary)
        .width('100%')
        .textAlign(TextAlign.End)
        .onClick(() => this.store.replaceAll(AppRoute.Home))
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
      AppButton({
        label: this.store.config?.splash.actionLabel ?? '立即体验',
        onTap: () => this.store.replaceAll(AppRoute.Home)
      })
    }
    .padding(AppSpacing.x6)
    .width('100%')
    .height('100%')
  }
}

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
