import SwiftUI

/// Phase-2 notch pill: compact vertical dark capsule of usage rings.
/// Hover expands horizontally and reveals a detail card with exact quota info.
struct NotchPillView: View {
    @Bindable var viewModel: NotchViewModel
    var onContentSizeChange: ((CGSize) -> Void)?

    private let collapsedSize = CGSize(width: 44, height: 118)
    private let expandedSize = CGSize(width: 248, height: 210)

    var body: some View {
        VStack(spacing: 0) {
            pillBody
                .padding(.top, 2)

            if viewModel.isExpanded, let focused = focusedUsage {
                UsageDetailCard(usage: focused)
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .transition(
                        .opacity
                            .combined(with: .move(edge: .top))
                            .combined(with: .scale(scale: 0.96, anchor: .top))
                    )
            }
        }
        .frame(
            width: viewModel.isExpanded ? expandedSize.width : collapsedSize.width,
            height: viewModel.isExpanded ? expandedSize.height : collapsedSize.height,
            alignment: .top
        )
        .background { pillBackground }
        .clipShape(RoundedRectangle(cornerRadius: viewModel.isExpanded ? 22 : 22, style: .continuous))
        .shadow(color: .black.opacity(viewModel.isExpanded ? 0.35 : 0.22), radius: viewModel.isExpanded ? 14 : 8, y: 4)
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: viewModel.isExpanded)
        .animation(.easeInOut(duration: 0.2), value: viewModel.focusedProvider)
        .onHover { hovering in
            viewModel.setExpanded(hovering)
            if hovering, viewModel.focusedProvider == nil {
                viewModel.focus(viewModel.usages.first?.provider)
            }
            reportSize()
        }
        .onChange(of: viewModel.isExpanded) { _, _ in
            reportSize()
        }
        .onAppear {
            reportSize()
        }
        .task {
            await viewModel.refresh()
        }
    }

    // MARK: - Subviews

    private var pillBody: some View {
        Group {
            if viewModel.isExpanded {
                expandedRings
            } else {
                collapsedRings
            }
        }
        .padding(.horizontal, viewModel.isExpanded ? 12 : 8)
        .padding(.vertical, viewModel.isExpanded ? 10 : 10)
    }

    private var collapsedRings: some View {
        VStack(spacing: 10) {
            ForEach(viewModel.usages) { usage in
                UsageRingCell(
                    usage: usage,
                    isFocused: false,
                    showsPercent: false,
                    ringSize: 26
                )
            }
        }
    }

    private var expandedRings: some View {
        HStack(spacing: 10) {
            ForEach(viewModel.usages) { usage in
                Button {
                    viewModel.focus(usage.provider)
                } label: {
                    UsageRingCell(
                        usage: usage,
                        isFocused: viewModel.focusedProvider == usage.provider,
                        showsPercent: true,
                        ringSize: 30
                    )
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background {
                        if viewModel.focusedProvider == usage.provider {
                            Capsule(style: .continuous)
                                .fill(usage.provider.accent.opacity(0.14))
                        }
                    }
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        viewModel.focus(usage.provider)
                    }
                }
            }
        }
    }

    private var pillBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.72),
                            Color.black.opacity(0.58)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
        }
    }

    private var focusedUsage: ProviderUsage? {
        if let focused = viewModel.focusedProvider {
            return viewModel.usages.first { $0.provider == focused }
        }
        return viewModel.usages.first
    }

    private func reportSize() {
        let size = viewModel.isExpanded ? expandedSize : collapsedSize
        onContentSizeChange?(size)
    }
}
