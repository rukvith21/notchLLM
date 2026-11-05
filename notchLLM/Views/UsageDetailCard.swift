import SwiftUI

/// CodeNotch-style hover tooltip: dark rounded card extending left with a right-side pointer.
struct UsageDetailCard: View {
    let usage: ProviderUsage

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                BrandIcon.view(for: usage.provider)
                    .frame(width: 13, height: 13)
                    .foregroundStyle(Color.white.opacity(0.95))
                    .padding(.top, 1.5)

                VStack(alignment: .leading, spacing: 2) {
                    Text(usage.provider.usageTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.96))
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.52))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 11)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black)
            )

            // Overlap 1pt so the tail reads as one shape with the card (no hairline gap).
            TooltipPointer()
                .fill(Color.black)
                .frame(width: 7, height: 11)
                .padding(.leading, -1)
        }
        .compositingGroup()
        .shadow(color: Color.black.opacity(0.50), radius: 9, x: -2, y: 2)
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(usage.provider.usageTitle). \(subtitle)")
    }

    private var subtitle: String {
        switch usage.status {
        case .loading:
            return "Refreshing…"
        case .error(let message):
            return message
        case .unavailable:
            return usage.detail
                ?? "Sign in to \(usage.provider.displayName) to read your usage"
        case .ready:
            switch usage.authState {
            case .unauthenticated:
                return "Sign in to \(usage.provider.displayName) to read your usage"
            case .apiKeyPresent, .manualOnly, .authenticated:
                if usage.usedFraction == nil {
                    return usage.detail
                        ?? "Signed in · no usage ledger yet"
                }
                if usage.source == .live {
                    return usage.detail ?? "\(usage.percentRemainingDisplay) remaining · \(usage.resetDisplay)"
                }
                if let detail = usage.detail, !detail.isEmpty, usage.source != .manual {
                    return "\(usage.percentRemainingDisplay) · \(usage.resetDisplay)"
                }
                return "\(usage.percentRemainingDisplay) remaining · \(usage.resetDisplay)"
            }
        }
    }
}

/// Small right-pointing triangle so the tooltip aims at the bar cell.
private struct TooltipPointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
