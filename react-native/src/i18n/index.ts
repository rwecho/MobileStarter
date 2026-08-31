import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import { zh } from './zh';
import { en } from './en';

// i18next + react-i18next（RN 社区标准）。默认 zh-CN；运行期语言由
// AppStore 依据用户 settings.language 调 setAppLanguage 切换，组件用 useTranslation。
void i18n.use(initReactI18next).init({
  resources: {
    'zh-CN': { translation: zh },
    'en-US': { translation: en },
  },
  lng: 'zh-CN',
  fallbackLng: 'zh-CN',
  interpolation: { escapeValue: false },
});

export default i18n;

export function setAppLanguage(language: string): void {
  if (language === i18n.language) return;
  void i18n.changeLanguage(language === 'en-US' ? 'en-US' : 'zh-CN');
}
