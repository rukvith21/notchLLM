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
                Spacer(minLength: 8)
                Text(usage.percentUsedDisplay)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(usage.provider.accent)
                    .monospacedDigit()
            }

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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(usage.provider.accent.opacity(0.35), lineWidth: 0.8)
                }
        }
    }
}
