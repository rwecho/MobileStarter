import { StyleSheet } from 'react-native';
import { colors, radii, spacing, ThemeColors } from './tokens';

export let styles = createStyles(colors);

export function applyTheme(palette: ThemeColors) {
  styles = createStyles(palette);
}

function createStyles(palette: ThemeColors) {
  return StyleSheet.create({
  safeArea: { flex: 1, backgroundColor: palette.background },
  page: { flex: 1, backgroundColor: palette.background },
  scrollContent: { padding: spacing.x4, gap: spacing.x4 },
  centered: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: spacing.x6,
    gap: spacing.x4,
  },
  title: { color: palette.text, fontSize: 28, fontWeight: '700' },
  heading: { color: palette.text, fontSize: 20, fontWeight: '700' },
  body: { color: palette.text, fontSize: 16 },
  secondary: { color: palette.textSecondary, fontSize: 14 },
  caption: { color: palette.textSecondary, fontSize: 12 },
  card: {
    backgroundColor: palette.surface,
    borderColor: palette.border,
    borderRadius: radii.card,
    borderWidth: 1,
    padding: spacing.x4,
    gap: spacing.x3,
  },
  sectionLabel: {
    color: palette.textSecondary,
    fontSize: 13,
    fontWeight: '600',
    marginLeft: spacing.x1,
  },
  row: {
    minHeight: 56,
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.x3,
    paddingHorizontal: spacing.x4,
    borderBottomColor: palette.border,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  rowText: { flex: 1, color: palette.text, fontSize: 16 },
  input: {
    minHeight: 52,
    borderWidth: 1,
    borderColor: palette.border,
    borderRadius: radii.control,
    backgroundColor: palette.surface,
    paddingHorizontal: spacing.x4,
    color: palette.text,
    fontSize: 16,
  },
  });
}
