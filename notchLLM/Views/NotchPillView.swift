import SwiftUI

/// CodeNotch-style slim vertical edge pill with white icon cells and a left tooltip.
struct NotchPillView: View {
    @Bindable var viewModel: NotchViewModel
    var onContentSizeChange: ((CGSize) -> Void)?

    /// Slim bar width hugging the screen edge (CodeNotch target ~40–44pt).
    private let barWidth: CGFloat = 42
    private let cellHeight: CGFloat = 48
    private let barVerticalPadding: CGFloat = 8
    private let cellSpacing: CGFloat = 2
    private let tooltipGap: CGFloat = 5
    private let tooltipColumnWidth: CGFloat = 232
    /// Extra panel padding so soft shadows / tails are not clipped by the NSPanel.
    private let shadowBleedLeading: CGFloat = 12
    private let shadowBleedTrailing: CGFloat = 2
    private let shadowBleedVertical: CGFloat = 10

    @State private var tooltipHeight: CGFloat = 42

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
        .padding(.leading, shadowBleedLeading)
        .padding(.trailing, shadowBleedTrailing)
        .padding(.vertical, shadowBleedVertical)
        .frame(width: panelSize.width, height: panelSize.height, alignment: .topTrailing)
        .animation(.easeOut(duration: 0.14), value: showsTooltip)
        .animation(.easeOut(duration: 0.14), value: viewModel.focusedProvider)
        .onPreferenceChange(TooltipHeightKey.self) { height in
            if height > 0 {
                tooltipHeight = height
            }
        }
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
        VStack(spacing: cellSpacing) {
            ForEach(viewModel.usages) { usage in
                cellButton(for: usage)
                    .frame(height: cellHeight)
            }
        }
        .padding(.vertical, barVerticalPadding)
        .frame(width: barWidth)
        .background {
            Capsule(style: .continuous)
                .fill(Color.black)
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                }
        }
        .compositingGroup()
        .shadow(color: Color.black.opacity(0.40), radius: 8, x: -1, y: 2)
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
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: TooltipHeightKey.self, value: geo.size.height)
                        }
                    )
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
                iconSize: 26
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
        let gaps = CGFloat(max(viewModel.usages.count - 1, 0)) * cellSpacing
        return CGFloat(viewModel.usages.count) * cellHeight + gaps + barVerticalPadding * 2
    }

    private var contentWidth: CGFloat {
        if showsTooltip {
            return tooltipColumnWidth + tooltipGap + barWidth
        }
        return barWidth
    }

    private var panelSize: CGSize {
        CGSize(
            width: contentWidth + shadowBleedLeading + shadowBleedTrailing,
            height: barHeight + shadowBleedVertical * 2
        )
    }

    private var focusedUsage: ProviderUsage? {
        if let focused = viewModel.focusedProvider {
            return viewModel.usages.first { $0.provider == focused }
        }
        return viewModel.usages.first
    }

    private func tooltipYOffset(for provider: ProviderKind) -> CGFloat {
        guard let index = viewModel.usages.firstIndex(where: { $0.provider == provider }) else {
            return 0
        }
        let gapOffset = CGFloat(index) * cellSpacing
        let cellCenter = barVerticalPadding + CGFloat(index) * cellHeight + gapOffset + cellHeight / 2
        let raw = cellCenter - tooltipHeight / 2
        let maxOffset = max(barHeight - tooltipHeight, 0)
        return min(max(raw, 0), maxOffset)
    }

    private func reportSize() {
        onContentSizeChange?(panelSize)
    }
}

private struct TooltipHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
