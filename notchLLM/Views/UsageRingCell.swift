import SwiftUI

/// CodeNotch-style cell: white monochrome icon in a circle, optional % underneath.
struct UsageRingCell: View {
    let usage: ProviderUsage
    var isFocused: Bool = false
    var showsPercent: Bool = true
    var iconSize: CGFloat = 28

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
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .strokeBorder(
                        isFocused ? Color.white.opacity(0.55) : Color.white.opacity(0.18),
                        lineWidth: isFocused ? 1.2 : 0.8
                    )
                    .frame(width: iconSize, height: iconSize)

                Image(systemName: usage.provider.systemImage)
                    .font(.system(size: iconSize * 0.42, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .symbolRenderingMode(.monochrome)
            }
            .opacity(iconOpacity)
            .frame(width: iconSize, height: iconSize)

            if showsPercent {
                Text(percentLabel)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.88))
                    .monospacedDigit()
                    .frame(height: 11)
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
