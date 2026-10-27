import SwiftUI

/// Compact circular usage indicator for one provider.
/// Phase 2 polishes stroke geometry / hover tooltips.
struct UsageRingCell: View {
    let usage: ProviderUsage

    private var progress: Double {
        usage.usedFraction ?? 0
    }

    private var isKnown: Bool {
        usage.usedFraction != nil
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(usage.provider.accent.opacity(0.25), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: isKnown ? progress : 0.08)
                .stroke(
                    usage.provider.accent.opacity(isKnown ? 1 : 0.45),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text(usage.provider.shortLabel)
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.85))
        }
        .frame(width: 22, height: 22)
        .help(helpText)
        .accessibilityLabel("\(usage.provider.displayName) usage")
        .accessibilityValue(accessibilityValue)
    }

    private var helpText: String {
        switch usage.status {
        case .ready:
            if let fraction = usage.usedFraction {
                return "\(usage.provider.displayName): \(Int(fraction * 100))% used"
            }
            return usage.provider.displayName
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
            return "\(Int(fraction * 100)) percent used"
        }
        return String(describing: usage.status)
    }
}
