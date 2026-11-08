import AppKit

final class TooltipPanel: NSPanel {
    private let label = NSTextField(labelWithString: "")

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .transient]

        label.textColor = .white
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor(white: 0.12, alpha: 0.96).cgColor
        content.layer?.cornerRadius = 7
        content.addSubview(label)
        contentView = content

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: content.topAnchor, constant: 7),
            label.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -7)
        ])
    }

    func show(_ text: String, at point: NSPoint) {
        label.stringValue = text
        let size = label.fittingSize
        let width = size.width + 20
        let height = size.height + 14
        setContentSize(NSSize(width: width, height: height))

        var origin = NSPoint(x: point.x - width / 2, y: point.y + 16)
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }) ?? NSScreen.main {
            origin.x = max(screen.frame.minX + 8, min(origin.x, screen.frame.maxX - width - 8))
            origin.y = max(screen.frame.minY + 8, min(origin.y, screen.frame.maxY - height - 8))
        }
        setFrameOrigin(origin)
        orderFrontRegardless()
    }

    func hide() {
        orderOut(nil)
    }
}
