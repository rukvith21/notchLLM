import SwiftUI

/// CodeNotch-style monochrome brand marks (path approximations of ChatGPT / Cursor / Gemini).
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

/// OpenAI-style interlocking blossom (simplified radial petals).
private struct ChatGPTMark: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let r = s * 0.40
            ZStack {
                ForEach(0..<6, id: \.self) { i in
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.95), lineWidth: max(s * 0.08, 1.0))
                        .frame(width: r * 0.38, height: r * 0.92)
                        .offset(y: -r * 0.28)
                        .rotationEffect(.degrees(Double(i) * 60))
                        .position(c)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Cursor chevron / caret mark.
private struct CursorMark: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let inset = s * 0.16
            Path { path in
                path.move(to: CGPoint(x: inset, y: geo.size.height * 0.64))
                path.addLine(to: CGPoint(x: geo.size.width / 2, y: inset))
                path.addLine(to: CGPoint(x: geo.size.width - inset, y: geo.size.height * 0.64))
            }
            .stroke(
                Color.white.opacity(0.95),
                style: StrokeStyle(lineWidth: max(s * 0.12, 1.3), lineCap: .round, lineJoin: .round)
            )
            Path { path in
                path.move(to: CGPoint(x: geo.size.width * 0.34, y: geo.size.height * 0.78))
                path.addLine(to: CGPoint(x: geo.size.width * 0.66, y: geo.size.height * 0.78))
            }
            .stroke(
                Color.white.opacity(0.85),
                style: StrokeStyle(lineWidth: max(s * 0.09, 1.1), lineCap: .round)
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// Gemini four-point sparkle.
private struct GeminiMark: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let outer = s * 0.46
            let inner = s * 0.13
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
