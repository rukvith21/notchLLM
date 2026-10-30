import SwiftUI

/// CodeNotch-style slim vertical edge pill with white icon cells and a left tooltip.
struct NotchPillView: View {
    @Bindable var viewModel: NotchViewModel
    var onContentSizeChange: ((CGSize) -> Void)?

    /// Slim bar width hugging the screen edge.
    private let barWidth: CGFloat = 52
    private let cellHeight: CGFloat = 52
    private let barVerticalPadding: CGFloat = 10
    private let tooltipGap: CGFloat = 10
    private let tooltipColumnWidth: CGFloat = 236

    private var showsTooltip: Bool {
        viewModel.isExpanded && viewModel.focusedProvider != nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if showsTooltip {
                tooltipColumn
                    .frame(width: tooltipColumnWidth, alignment: .trailing)
                    .padding(.trailing, tooltipGap)
                    .transition(.opacity)
            }

            barColumn
                .frame(width: barWidth)
        }
        .frame(width: panelSize.width, height: panelSize.height, alignment: .topTrailing)
        .animation(.easeOut(duration: 0.14), value: showsTooltip)
        .animation(.easeOut(duration: 0.14), value: viewModel.focusedProvider)
        .onChange(of: panelSize) { _, _ in
            reportSize()
        }
        .onAppear {
            reportSize()
        }
        .task {
            await viewModel.refresh()
        }
    }

    // MARK: - Columns

    private var barColumn: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.usages.enumerated()), id: \.element.id) { index, usage in
                cellButton(for: usage)
                    .frame(height: cellHeight)

                if index < viewModel.usages.count - 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 0.5)
                        .padding(.horizontal, 10)
                }
            }
        }
        .padding(.vertical, barVerticalPadding)
        .frame(width: barWidth)
        .background {
            Capsule(style: .continuous)
                .fill(Color.black)
        }
        .compositingGroup()
        .onHover { hovering in
            viewModel.setExpanded(hovering)
            if hovering, viewModel.focusedProvider == nil {
                viewModel.focus(viewModel.usages.first?.provider)
            }
        }
    }

    private var tooltipColumn: some View {
        ZStack(alignment: .trailing) {
            // Absorb hover while the pointer moves onto the tooltip so it does not flicker away.
            Color.black.opacity(0.001)
                .onHover { hovering in
                    if hovering {
                        viewModel.setExpanded(true)
                    } else if viewModel.focusedProvider == nil {
                        viewModel.setExpanded(false)
                    }
                }

            if let focused = focusedUsage {
                UsageDetailCard(usage: focused)
                    .offset(y: tooltipYOffset(for: focused.provider))
            }
        }
        .frame(height: barHeight, alignment: .top)
    }

    private func cellButton(for usage: ProviderUsage) -> some View {
        Button {
            viewModel.focus(usage.provider)
        } label: {
            UsageRingCell(
                usage: usage,
                isFocused: viewModel.focusedProvider == usage.provider,
                showsPercent: true,
                iconSize: 28
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                viewModel.focus(usage.provider)
            }
        }
    }

    // MARK: - Layout math

    private var barHeight: CGFloat {
        let separators = CGFloat(max(viewModel.usages.count - 1, 0)) * 0.5
        return CGFloat(viewModel.usages.count) * cellHeight + separators + barVerticalPadding * 2
    }

    private var panelSize: CGSize {
        if showsTooltip {
            return CGSize(width: tooltipColumnWidth + tooltipGap + barWidth, height: barHeight)
        }
        return CGSize(width: barWidth, height: barHeight)
    }

    private var focusedUsage: ProviderUsage? {
        if let focused = viewModel.focusedProvider {
            return viewModel.usages.first { $0.provider == focused }
        }
        return viewModel.usages.first
    }

    private func tooltipYOffset(for provider: ProviderKind) -> CGFloat {
        guard let index = viewModel.usages.firstIndex(where: { $0.provider == provider }) else {
            return barVerticalPadding
        }
        let separatorOffset = CGFloat(index) * 0.5
        let cellCenter = barVerticalPadding + CGFloat(index) * cellHeight + separatorOffset + cellHeight / 2
        return cellCenter - 21
    }

    private func reportSize() {
        onContentSizeChange?(panelSize)
    }
}
