import SwiftUI

/// CodeNotch-style hover tooltip: dark rounded card extending left with a right-side pointer.
struct UsageDetailCard: View {
    let usage: ProviderUsage

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: usage.provider.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .symbolRenderingMode(.monochrome)
                    .frame(width: 16, height: 16)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(usage.provider.usageTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.95))
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black)
            )

            TooltipPointer()
                .fill(Color.black)
                .frame(width: 8, height: 14)
                .padding(.leading, -1)
        }
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
                if let detail = usage.detail, !detail.isEmpty {
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
