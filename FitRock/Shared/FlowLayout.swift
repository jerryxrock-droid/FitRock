import SwiftUI

/// A horizontal wrapping layout used for muscle tags, equipment tags, etc.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentRowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                height += currentRowHeight + spacing
                currentX = 0
                currentRowHeight = 0
            }
            currentX += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
        height += currentRowHeight
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let maxWidth = bounds.width
        var y: CGFloat = bounds.minY
        var currentX: CGFloat = bounds.minX
        var currentRowHeight: CGFloat = 0
        var rowViews: [(view: LayoutSubviews.Element, x: CGFloat, size: CGSize)] = []

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > bounds.minX {
                placeRow(rowViews, at: y)
                y += currentRowHeight + spacing
                currentX = bounds.minX
                currentRowHeight = 0
                rowViews.removeAll()
            }
            rowViews.append((view, currentX, size))
            currentX += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
        placeRow(rowViews, at: y)
    }

    private func placeRow(_ row: [(view: LayoutSubviews.Element, x: CGFloat, size: CGSize)], at y: CGFloat) {
        for item in row {
            item.view.place(at: CGPoint(x: item.x, y: y), proposal: ProposedViewSize(item.size))
        }
    }
}
