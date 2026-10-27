import SwiftUI

/// Phase-1 pill hosted inside the floating `NotchPanel`.
/// Visual polish (materials, spacing, hover expand) is Phase 2.
struct NotchPillView: View {
    @Bindable var viewModel: NotchViewModel

    var body: some View {
        HStack(spacing: 8) {
            ForEach(viewModel.usages) { usage in
                UsageRingCell(usage: usage)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await viewModel.refresh()
        }
    }
}
