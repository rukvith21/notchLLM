import SwiftUI

/// Compact circular usage indicator for one provider.
struct UsageRingCell: View {
    let usage: ProviderUsage
    var isFocused: Bool = false
    var showsPercent: Bool = false
    var ringSize: CGFloat = 26

    private var progress: Double {
        usage.usedFraction ?? 0
    }

    private var isKnown: Bool {
        usage.usedFraction != nil && usage.status != .unavailable
    }

    private var lineWidth: CGFloat {
        ringSize > 28 ? 3.0 : 2.4
    }

    private var ringOpacity: Double {
        switch usage.status {
        case .loading: 0.55
        case .unavailable, .error: 0.4
        case .ready: usage.source == .degraded ? 0.75 : 1.0
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: lineWidth)

                Circle()
                    .stroke(usage.provider.accent.opacity(0.28), lineWidth: lineWidth)

                Circle()
                    .trim(from: 0, to: isKnown ? progress : 0.06)
                    .stroke(
                        AngularGradient(
                            colors: [
                                usage.provider.accent.opacity(0.75),
                                usage.provider.accent
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.55), value: progress)

                Image(systemName: usage.provider.systemImage)
                    .font(.system(size: ringSize * 0.32, weight: .semibold))
                    .foregroundStyle(usage.provider.accent)
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: ringSize, height: ringSize)
            .opacity(ringOpacity)
            .scaleEffect(isFocused ? 1.08 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isFocused)

            if showsPercent {
                VStack(alignment: .leading, spacing: 0) {
                    Text(usage.provider.shortLabel)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                    Text(usage.percentUsedDisplay)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .monospacedDigit()
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .leading)),
                    removal: .opacity
                ))
            }
        }
        .help(helpText)
        .accessibilityLabel("\(usage.provider.displayName) usage")
        .accessibilityValue(accessibilityValue)
    }

    private var helpText: String {
        switch usage.status {
        case .ready:
            return "\(usage.provider.displayName): \(usage.percentUsedDisplay) · \(usage.tokensUsedDisplay) · \(usage.resetDisplay)"
        case .loading:
            return "\(usage.provider.displayName): refreshing…"
        case .unavailable:
            return "\(usage.provider.displayName): \(usage.detail ?? "unavailable")"
        case .error(let message):
            return "\(usage.provider.displayName): \(message)"
        }
    }

    private var accessibilityValue: String {
        if let fraction = usage.usedFraction {
            return "\(Int((fraction * 100).rounded())) percent used"
        }
        return String(describing: usage.status)
    }
}
