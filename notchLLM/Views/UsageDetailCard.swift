import SwiftUI

/// Expanded detail strip shown on hover — exact %, tokens, reset timer.
struct UsageDetailCard: View {
    let usage: ProviderUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: usage.provider.systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(usage.provider.accent)
                Text(usage.provider.displayName)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                Text(usage.sourceBadge)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(statusTint.opacity(0.9))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(statusTint.opacity(0.15)))
                Spacer(minLength: 8)
                Text(usage.percentUsedDisplay)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(usage.provider.accent)
                    .monospacedDigit()
            }

            if case .error(let message) = usage.status {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.orange.opacity(0.9))
            } else if usage.status == .unavailable {
                Label(usage.detail ?? "Unavailable", systemImage: "moon.zzz")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            } else if usage.status == .loading {
                Label("Refreshing…", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            } else {
                ProgressView(value: usage.usedFraction ?? 0)
                    .progressViewStyle(.linear)
                    .tint(usage.provider.accent)
                    .scaleEffect(x: 1, y: 0.7, anchor: .center)

                HStack {
                    Label(usage.tokensUsedDisplay, systemImage: "number")
                    Spacer(minLength: 8)
                    Text(usage.tokensLeftDisplay)
                        .foregroundStyle(.white.opacity(0.55))
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))

                Label(usage.resetDisplay, systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
            }

            if let detail = usage.detail, usage.status == .ready {
                Text(detail)
                    .font(.system(size: 9, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(statusTint.opacity(0.35), lineWidth: 0.8)
                }
        }
    }

    private var statusTint: Color {
        switch usage.status {
        case .error: .orange
        case .unavailable: .white.opacity(0.45)
        case .loading: .white.opacity(0.55)
        case .ready:
            usage.source == .degraded ? .orange.opacity(0.85) : usage.provider.accent
        }
    }
}
