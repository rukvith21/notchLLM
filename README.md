# notchLLM

Native macOS LSUIElement utility that floats a usage pill beside the hardware notch (or top-center on non-notch displays). Tracks Gemini / ChatGPT / Cursor quota at a glance.

## Current (Phases 1–3)

- Dock-less background agent (`LSUIElement` + `.accessory` activation policy)
- Borderless, non-activating `NSPanel` at `.statusBar` level with `.fullScreenAuxiliary`
- Multi-display / screen-change repositioning via `ScreenGeometry` + `DisplayObserver`
- Vertical notch pill with hover-expand usage rings (Phase 2)
- Async adapters for Gemini / ChatGPT / Cursor with local session detection + manual caps (Phase 3)
- See [docs/ADAPTERS.md](docs/ADAPTERS.md) for auth/fallback assumptions

## Open in Xcode

```bash
open /Users/challarukvithreddy/git-proj/notchLLM/notchLLM.xcodeproj
```

## Build

```bash
xcodebuild -project notchLLM.xcodeproj -scheme notchLLM -configuration Debug build
```

## Layout

```
notchLLM/
  App/           SwiftUI entry + AppDelegate
  Windows/       NotchPanel + NotchPanelController
  Views/         Pill + usage ring cells
  ViewModels/    NotchViewModel
  Models/        ProviderKind / ProviderUsage
  Services/      Aggregator + provider stubs
  Utilities/     ScreenGeometry + DisplayObserver
```
