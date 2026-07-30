# Flutter rules

In addition to `/AGENTS.md`:

- Use Dart 3 sealed classes for view state and immutable `const` models.
- Use one controller per feature flow; UI receives state and emits typed events.
- Never call `Navigator` below a page-level coordinator. Route names come from
  `AppRoute`.
- A `build` method may not exceed 80 lines or six widget levels.
- Prefer small `StatelessWidget` classes over private methods returning widgets.
- Use `flutter_svg`; every icon path is declared in the asset catalog.
- Do not use `IconData`, Material/Cupertino icon fonts, emoji, or text glyphs as
  icons.
- Enable `flutter_lints`; warnings are build failures.
- Dispose every controller/subscription and check mounted state after awaits.
- Widget tests cover route guards, forms, dialogs, and all async UI states.

