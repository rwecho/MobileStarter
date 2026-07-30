# MobileUI repository rules

These rules apply to every project in this repository. A platform-level
`AGENTS.md` may add stricter rules but may not relax these rules.

## Architecture

- Use feature-first modules. A feature owns its UI, state, domain contracts, and
  data adapters. Cross-feature code belongs in `core`, `shared`, or `design_system`.
- Dependencies point inward: `presentation -> application -> domain`. Platform
  and data implementations depend on domain contracts, never the reverse.
- Pages may compose features, but must not call HTTP, persistence, billing, or
  platform APIs directly.
- A file has one primary responsibility and one public component/class unless a
  small private helper is inseparable from it.

## Size and nesting limits

- Source file: target <= 250 lines; hard limit 350 lines.
- Page/screen component: target <= 180 lines.
- Function/method: target <= 40 lines; hard limit 60 lines.
- UI render/build function: target <= 80 lines.
- Cyclomatic complexity: <= 10 per function.
- Logic nesting (`if`, loop, `switch`, callbacks): <= 3 levels.
- Declarative UI nesting: <= 6 visible levels. Extract a named component at the
  fourth meaningful layout level when the subtree has behavior or repetition.
- Function parameters: <= 5. Use an immutable parameter object beyond that.
- Boolean parameters: at most one; prefer an enum for multiple modes.

## State and navigation

- Model asynchronous state explicitly as `idle | loading | success | empty |
  error | offline | unauthorized`. Do not represent it with multiple booleans.
- State is immutable. State transitions happen only in a controller/view-model/
  store, never in leaf UI components.
- Routes are typed and centralized. Do not navigate with ad-hoc string literals.
- Route parameters must be serializable and validated at the route boundary.
- Authentication redirects, onboarding, promotion display, and deep links are
  route guards, not page-level conditional navigation.
- Every recoverable error exposes a retry action. Loading actions are idempotent
  and disabled while pending.

## Design system and assets

- Screens use design tokens; literal colors, spacing, radii, typography, and
  shadows are forbidden outside the design-system token files.
- Every icon must be an SVG asset or an SVG component. Emoji, Unicode pictograms,
  font glyphs, and text characters used as icons are forbidden.
- Icon buttons require an accessible label and a minimum 44x44 logical-pixel hit
  target.
- Product imagery belongs in `assets/images`; illustrations must include a
  light/dark strategy and an attribution/license note when external.
- Reusable feedback components are mandatory: toast, alert, confirm dialog,
  bottom sheet, loading, empty, offline, and permission request.

## Quality

- No swallowed errors, empty catches, debug prints, or untracked TODOs.
- User-facing strings go through localization, including validation messages.
- Sensitive values never appear in logs, route URLs, analytics, or persisted UI
  state.
- Each feature has unit tests for state transitions and navigation tests for its
  critical path.
- Accessibility: semantic labels, dynamic text support, keyboard/focus order,
  contrast, reduced motion, and screen-reader announcements are required.

## Definition of done

- Format, lint, type-check, architecture checks, and available tests pass.
- Loading, empty, error, offline, and unauthorized states are considered.
- Light and dark themes render without literal-color drift.
- No emoji/icon-font fallback exists.
- Flutter, React Native, and ArkTS expose the same route names and state meaning.

