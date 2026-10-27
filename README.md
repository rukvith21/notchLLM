# notchLLM

Native macOS LSUIElement utility that floats a usage pill beside the hardware notch (or top-center on non-notch displays). Tracks Gemini / ChatGPT / Cursor quota at a glance.

## Phase 1 (current)

- Dock-less background agent (`LSUIElement` + `.accessory` activation policy)
- Borderless, non-activating `NSPanel` at `.statusBar` level with `.fullScreenAuxiliary`
- Multi-display / screen-change repositioning via `ScreenGeometry` + `DisplayObserver`
- MVVM skeleton with provider stubs (Gemini, ChatGPT, Cursor)

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
