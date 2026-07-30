# ArkTS rules

In addition to `/AGENTS.md`:

- Use Stage model and ArkUI declarative components.
- Pages only compose components and bind a typed ViewModel.
- Use typed enums/unions for routes and async states; no string page routing.
- `build()` is at most 80 lines and ArkUI nesting is at most six levels.
- Extract repeated layout into `@Component` structs, not large `@Builder`
  blocks. Builders are limited to 40 lines.
- Do not use `any`, `Object`, implicit dynamic maps, or untyped JSON beyond an
  adapter boundary.
- SVG files live in `resources/base/media`; use resource references for icons.
  Emoji and text glyph icons are forbidden.
- Persistent and distributed data access is isolated behind repositories.
- UIAbility lifecycle code contains no feature business logic.
- ArkTSCheck and Hvigor build warnings are treated as failures.

