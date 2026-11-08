import AppKit

final class StatusMenuButton: NSButton {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private var hoverTrackingArea: NSTrackingArea?

    var itemTitle = "" {
        didSet {
            titleLabel.stringValue = itemTitle
            setAccessibilityLabel(itemTitle)
        }
    }

    var itemImage: NSImage? {
        didSet { iconView.image = itemImage }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureContent()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureContent()
    }

    private func configureContent() {
        title = ""
        wantsLayer = true
        layer?.cornerRadius = 6

        iconView.contentTintColor = .labelColor
        titleLabel.font = .systemFont(ofSize: 14)
        titleLabel.textColor = .labelColor

        let content = NSStackView(views: [iconView, titleLabel])
        content.orientation = .horizontal
        content.alignment = .centerY
        content.spacing = 8
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            content.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
            content.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.08).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        layer?.backgroundColor = nil
    }
}
