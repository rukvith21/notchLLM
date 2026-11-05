import SwiftUI

/// CodeNotch-style monochrome brand marks (ChatGPT blossom / Cursor caret / Gemini sparkle).
enum BrandIcon {
    @ViewBuilder
    static func view(for kind: ProviderKind) -> some View {
        switch kind {
        case .chatGPT:
            ChatGPTMark()
        case .cursor:
            CursorMark()
        case .gemini:
            GeminiMark()
        }
    }
}

/// OpenAI interlocking hex blossom — six elliptical petals.
private struct ChatGPTMark: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let petalLen = s * 0.46
            let petalWid = s * 0.18
            ZStack {
                ForEach(0..<6, id: \.self) { i in
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.95), lineWidth: max(s * 0.075, 0.9))
                        .frame(width: petalWid, height: petalLen)
                        .offset(y: -petalLen * 0.22)
                        .rotationEffect(.degrees(Double(i) * 60))
                        .position(c)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Cursor upward caret (CodeNotch chevron) — single open V, no underline.
private struct CursorMark: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let insetX = s * 0.14
            let top = s * 0.18
            let bottom = s * 0.78
            Path { path in
                path.move(to: CGPoint(x: insetX, y: bottom))
                path.addLine(to: CGPoint(x: geo.size.width / 2, y: top))
                path.addLine(to: CGPoint(x: geo.size.width - insetX, y: bottom))
            }
            .stroke(
                Color.white.opacity(0.95),
                style: StrokeStyle(lineWidth: max(s * 0.14, 1.4), lineCap: .round, lineJoin: .round)
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Gemini four-point sparkle (soft diamond star).
private struct GeminiMark: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let outer = s * 0.48
            let inner = s * 0.11
            Path { path in
                for i in 0..<8 {
                    let angle = Double(i) * (.pi / 4) - .pi / 2
                    let radius = i.isMultiple(of: 2) ? outer : inner
                    let point = CGPoint(x: c.x + cos(angle) * radius, y: c.y + sin(angle) * radius)
                    if i == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
                path.closeSubpath()
            }
            .fill(Color.white.opacity(0.95))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
