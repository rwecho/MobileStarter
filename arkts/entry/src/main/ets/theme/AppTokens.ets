interface ColorPalette {
  background: ResourceColor
  surface: ResourceColor
  surfaceMuted: ResourceColor
  text: ResourceColor
  textSecondary: ResourceColor
  border: ResourceColor
  brand: ResourceColor
  brandSoft: ResourceColor
  success: ResourceColor
  warning: ResourceColor
  error: ResourceColor
}

const LIGHT: ColorPalette = {
  background: '#F6F7F9',
  surface: '#FFFFFF',
  surfaceMuted: '#F1F3F5',
  text: '#17191D',
  textSecondary: '#667085',
  border: '#E4E7EC',
  brand: '#A84444',
  brandSoft: '#F6E9E9',
  success: '#2C9A5E',
  warning: '#D58B21',
  error: '#D24B4B'
}

const DARK: ColorPalette = {
  background: '#0F1115',
  surface: '#1A1D24',
  surfaceMuted: '#23272F',
  text: '#E6E8EC',
  textSecondary: '#9AA1AD',
  border: '#2C313A',
  brand: '#C25C5C',
  brandSoft: '#3A2222',
  success: '#3DBB7A',
  warning: '#E0A24A',
  error: '#E06C6C'
}

// Mutable so applyColorScheme can swap the whole palette at runtime. Components
// re-read these statics on every rebuild, so a store change (e.g. busy toggle
// after saveSettings) re-renders the tree with the new colors.
export class AppColors {
  static background: ResourceColor = LIGHT.background
  static surface: ResourceColor = LIGHT.surface
  static surfaceMuted: ResourceColor = LIGHT.surfaceMuted
  static text: ResourceColor = LIGHT.text
  static textSecondary: ResourceColor = LIGHT.textSecondary
  static border: ResourceColor = LIGHT.border
  static brand: ResourceColor = LIGHT.brand
  static brandSoft: ResourceColor = LIGHT.brandSoft
  static success: ResourceColor = LIGHT.success
  static warning: ResourceColor = LIGHT.warning
  static error: ResourceColor = LIGHT.error
}

export function applyColorScheme(isDark: boolean): void {
  const p = isDark ? DARK : LIGHT
  AppColors.background = p.background
  AppColors.surface = p.surface
  AppColors.surfaceMuted = p.surfaceMuted
  AppColors.text = p.text
  AppColors.textSecondary = p.textSecondary
  AppColors.border = p.border
  AppColors.brand = p.brand
  AppColors.brandSoft = p.brandSoft
  AppColors.success = p.success
  AppColors.warning = p.warning
  AppColors.error = p.error
}

export class AppSpacing {
  static readonly x1: number = 4
  static readonly x2: number = 8
  static readonly x3: number = 12
  static readonly x4: number = 16
  static readonly x5: number = 20
  static readonly x6: number = 24
}

export class AppRadii {
  static readonly small: number = 10
  static readonly control: number = 12
  static readonly card: number = 16
  static readonly sheet: number = 24
}
