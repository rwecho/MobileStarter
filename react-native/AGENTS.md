# React Native rules

In addition to `/AGENTS.md`:

- TypeScript strict mode is mandatory; `any`, non-null assertions, and
  `@ts-ignore` are forbidden.
- Components are function components. Hooks live at the top level and custom
  hooks own effects/subscriptions.
- Use discriminated unions for view state and typed route params.
- JSX nesting is at most six levels; extract named components at four meaningful
  levels.
- Component files target <= 180 lines and never exceed 250 lines.
- Styles use `StyleSheet.create` and design tokens; no inline literal styling.
- Use `react-native-svg` for icons. Emoji, icon fonts, and glyph characters are
  forbidden.
- Reducers/state stores are pure. No side effects during render.
- Every effect has a dependency audit and cleanup when it owns a subscription.
- ESLint, Prettier, TypeScript, and tests must pass with zero warnings.

