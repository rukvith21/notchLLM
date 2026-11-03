import SwiftUI

/// CodeNotch-style cell: white monochrome brand icon, optional coral remaining ring + % underneath.
struct UsageRingCell: View {
    let usage: ProviderUsage
    var isFocused: Bool = false
    var showsPercent: Bool = true
    var iconSize: CGFloat = 24

    /// Warm coral used by CodeNotch for known remaining rings (see target screenshot).
    private static let remainingRing = Color(red: 1.0, green: 0.42, blue: 0.22)

    private var remainingFraction: Double? {
        guard let used = usage.usedFraction else { return nil }
        return max(0, min(1, 1 - used))
    }

    private var percentLabel: String {
        guard let remaining = remainingFraction, usage.status == .ready || usage.status == .loading else {
            return "—"
        }
        return "\(Int((remaining * 100).rounded()))%"
    }

    private var iconOpacity: Double {
        switch usage.status {
        case .loading: 0.55
        case .unavailable, .error: 0.45
        case .ready: 1.0
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                // Dim track
                Circle()
                    .strokeBorder(
                        Color.white.opacity(isFocused ? 0.30 : 0.12),
                        lineWidth: 1.35
                    )

                // Remaining arc when quota is known (CodeNotch coral ring).
                if let remaining = remainingFraction {
                    Circle()
                        .trim(from: 0, to: remaining)
                        .stroke(
                            Self.remainingRing.opacity(usage.status == .ready ? 1 : 0.55),
                            style: StrokeStyle(lineWidth: 1.65, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                } else if isFocused {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.55), lineWidth: 1.05)
                }

                BrandIcon.view(for: usage.provider)
                    .frame(width: iconSize * 0.52, height: iconSize * 0.52)
                    .foregroundStyle(Color.white.opacity(0.95))
            }
            .opacity(iconOpacity)
            .frame(width: iconSize, height: iconSize)

            if showsPercent {
                Text(percentLabel)
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.90))
                    .monospacedDigit()
                    .frame(height: 10)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("\(usage.provider.displayName) usage")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        if let remaining = remainingFraction {
            return "\(Int((remaining * 100).rounded())) percent remaining"
        }
        return String(describing: usage.status)
    }
}
