import AppKit
import InputSwitchCore

final class ContributionHeatmapView: NSView {
    var entries: [DailyCount] = [] {
        didSet {
            needsDisplay = true
            updateAccessibilityValue()
            refreshTrackingAreas()
        }
    }

    private struct Cell {
        let entry: DailyCount
        let rect: NSRect
        let column: Int
    }

    private struct Layout {
        let cells: [Cell]
        let columns: Int
        let cellSize: CGFloat
        let spacing: CGFloat
        let labelWidth: CGFloat
        let top: CGFloat
        let scale: CGFloat
    }

    private static let lightPalette = [
        color(235, 237, 240), color(155, 233, 168), color(64, 196, 99), color(48, 161, 78), color(33, 110, 57)
    ]
    private static let darkPalette = [
        color(22, 27, 34), color(14, 68, 41), color(0, 109, 50), color(38, 166, 65), color(57, 211, 83)
    ]
    private static let palette: [NSColor] = (0..<5).map { level in
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? darkPalette[level] : lightPalette[level]
        }
    }

    private var installedTrackingAreas: [NSTrackingArea] = []
    private var installedBounds: NSRect?
    private var installedEntries: [DailyCount]?
    private var hoveredArea: NSTrackingArea?
    private var hoveredEntry: DailyCount?
    private var tooltipWorkItem: DispatchWorkItem?
    private lazy var tooltipPanel = TooltipPanel()

    override var isFlipped: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        setAccessibilityLabel("年度切换热力图")
        setAccessibilityRole(.list)
        refreshTrackingAreas()
    }

    override func layout() {
        super.layout()
        refreshTrackingAreas()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let layout = makeLayout() else { return }

        drawMonths(layout: layout)
        drawWeekdays(layout: layout)

        let maximum = entries.map(\.count).max() ?? 0
        for cell in layout.cells {
            color(for: cell.entry.count, maximum: maximum).setFill()
            NSBezierPath(roundedRect: cell.rect, xRadius: 2 * layout.scale, yRadius: 2 * layout.scale).fill()
        }
        drawFooter(originY: bounds.height - 12 * layout.scale, scale: layout.scale)
    }

    override func mouseEntered(with event: NSEvent) {
        guard let area = event.trackingArea,
              let index = area.userInfo?["index"] as? Int,
              let cells = makeLayout()?.cells,
              cells.indices.contains(index) else { return }

        let entry = cells[index].entry
        tooltipWorkItem?.cancel()
        hoveredArea = area
        hoveredEntry = entry
        let workItem = DispatchWorkItem { [weak self] in
            self?.showTooltip(for: entry)
        }
        tooltipWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }

    override func mouseExited(with event: NSEvent) {
        guard event.trackingArea === hoveredArea else { return }
        cancelTooltip()
    }

    deinit {
        tooltipWorkItem?.cancel()
        tooltipPanel.hide()
    }

    private func showTooltip(for entry: DailyCount) {
        guard hoveredEntry == entry, window?.isVisible == true else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        tooltipPanel.show(
            "\(formatter.string(from: entry.date))：\(entry.count) 次自动切换",
            at: NSEvent.mouseLocation
        )
    }

    private func cancelTooltip() {
        tooltipWorkItem?.cancel()
        tooltipWorkItem = nil
        tooltipPanel.hide()
        hoveredArea = nil
        hoveredEntry = nil
    }

    private func makeLayout() -> Layout? {
        guard let first = entries.first, !entries.isEmpty, bounds.width > 100 else { return nil }

        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: first.date)
        guard let gridStart = calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: first.date) else { return nil }

        let offsets = entries.compactMap { entry -> (entry: DailyCount, offset: Int)? in
            guard let offset = calendar.dateComponents([.day], from: gridStart, to: entry.date).day else { return nil }
            return (entry, offset)
        }
        guard let last = offsets.last else { return nil }
        let columns = last.offset / 7 + 1

        let baseLabelWidth: CGFloat = 32
        let baseTop: CGFloat = 18
        let baseBottom: CGFloat = 26
        let baseCellSize: CGFloat = 10
        let baseSpacing: CGFloat = 3
        let baseWidth = baseLabelWidth + CGFloat(columns) * baseCellSize + CGFloat(columns - 1) * baseSpacing
        let baseHeight = baseTop + 7 * baseCellSize + 6 * baseSpacing + baseBottom
        let scale = min(bounds.width / baseWidth, bounds.height / baseHeight)
        guard scale > 0 else { return nil }

        let cellSize = baseCellSize * scale
        let spacing = baseSpacing * scale
        let labelWidth = baseLabelWidth * scale
        let top = baseTop * scale
        let cells = offsets.map { item in
            let column = item.offset / 7
            let row = item.offset % 7
            return Cell(
                entry: item.entry,
                rect: NSRect(
                    x: labelWidth + CGFloat(column) * (cellSize + spacing),
                    y: top + CGFloat(row) * (cellSize + spacing),
                    width: cellSize,
                    height: cellSize
                ),
                column: column
            )
        }
        return Layout(
            cells: cells,
            columns: columns,
            cellSize: cellSize,
            spacing: spacing,
            labelWidth: labelWidth,
            top: top,
            scale: scale
        )
    }

    private func refreshTrackingAreas() {
        guard installedBounds != bounds || installedEntries != entries else { return }
        installedBounds = bounds
        installedEntries = entries
        cancelTooltip()
        installedTrackingAreas.forEach(removeTrackingArea)
        installedTrackingAreas.removeAll()

        guard let layout = makeLayout() else { return }
        for (index, cell) in layout.cells.enumerated() {
            let area = NSTrackingArea(
                rect: cell.rect,
                options: [.mouseEnteredAndExited, .activeInKeyWindow],
                owner: self,
                userInfo: ["index": index]
            )
            addTrackingArea(area)
            installedTrackingAreas.append(area)
        }
    }

    private func color(for count: Int, maximum: Int) -> NSColor {
        guard count > 0, maximum > 0 else { return Self.palette[0] }
        let ratio = CGFloat(count) / CGFloat(maximum)
        switch ratio {
        case ..<0.25: return Self.palette[1]
        case ..<0.50: return Self.palette[2]
        case ..<0.75: return Self.palette[3]
        default: return Self.palette[4]
        }
    }

    private func drawMonths(layout: Layout) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM"
        var previousMonth = -1
        for column in 0..<layout.columns {
            guard let cell = layout.cells.first(where: { $0.column == column }) else { continue }
            let month = Calendar.current.component(.month, from: cell.entry.date)
            if column == 0 || month != previousMonth {
                let x = layout.labelWidth + CGFloat(column) * (layout.cellSize + layout.spacing)
                drawText(formatter.string(from: cell.entry.date), at: NSPoint(x: x, y: 0), size: 9 * layout.scale)
            }
            previousMonth = month
        }
    }

    private func drawWeekdays(layout: Layout) {
        for (row, label) in [(0, "Mon"), (2, "Wed"), (4, "Fri")] {
            let y = layout.top + CGFloat(row) * (layout.cellSize + layout.spacing)
                + (layout.cellSize - 10 * layout.scale) / 2
            drawText(label, at: NSPoint(x: 0, y: y), size: 9 * layout.scale)
        }
    }

    private func drawFooter(originY: CGFloat, scale: CGFloat) {
        drawText("仅统计真实自动切换", at: NSPoint(x: 0, y: originY), size: 9 * scale)
        drawText("Less", at: NSPoint(x: bounds.width - 126 * scale, y: originY), size: 9 * scale)
        for level in 0..<5 {
            let rect = NSRect(
                x: bounds.width - 105 * scale + CGFloat(level) * 12 * scale,
                y: originY,
                width: 9 * scale,
                height: 9 * scale
            )
            Self.palette[level].setFill()
            NSBezierPath(roundedRect: rect, xRadius: 2 * scale, yRadius: 2 * scale).fill()
        }
        drawText("More", at: NSPoint(x: bounds.width - 40 * scale, y: originY), size: 9 * scale)
    }

    private func drawText(_ text: String, at point: NSPoint, size: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        (text as NSString).draw(at: point, withAttributes: attributes)
    }

    private func updateAccessibilityValue() {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        setAccessibilityValue(entries.map {
            "\(formatter.string(from: $0.date)) \(String($0.count))次"
        }.joined(separator: "，"))
    }

    private static func color(_ red: Double, _ green: Double, _ blue: Double) -> NSColor {
        NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: 1)
    }
}
