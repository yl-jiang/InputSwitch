import AppKit
import Combine
import InputSwitchCore

final class FlippedStackView: NSStackView {
    override var isFlipped: Bool { true }
}

final class CardView: NSView {
    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        super.updateLayer()
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        layer?.borderWidth = 1
        layer?.cornerRadius = 14
    }
}

final class StatisticsViewController: NSViewController {
    private let store: SwitchEventStore
    private let scrollView = NSScrollView()
    private var cancellables = Set<AnyCancellable>()
    private var dataSections: [NSView] = []
    private var contentStack: NSStackView!

    private let shareButton = NSButton(title: "分享", target: nil, action: nil)
    private let todayCountLabel = NSTextField(labelWithString: "0")
    private let yearControl = NSPopUpButton()
    private let chartTitleLabel = NSTextField(labelWithString: "")
    private let chartView = ContributionHeatmapView()
    private let appsStack = NSStackView()
    private let recentStack = NSStackView()
    private let emptyView = NSView()
    private let errorLabel = NSTextField(labelWithString: "")

    init(store: SwitchEventStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 760, height: 600))
        configureLayout()
        bindState()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        updateStatistics()
        view.layoutSubtreeIfNeeded()
        scrollView.contentView.scrollToVisible(NSRect(x: 0, y: 0, width: 1, height: 1))
    }

    private func configureLayout() {
        let title = NSTextField(labelWithString: "使用统计")
        title.font = .systemFont(ofSize: 22, weight: .bold)
        shareButton.target = self
        shareButton.action = #selector(share)
        shareButton.bezelStyle = .rounded
        let header = NSStackView(views: [title, NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1)), shareButton])
        header.orientation = .horizontal

        let summary = NSStackView()
        summary.orientation = .vertical
        summary.alignment = .leading
        summary.spacing = 4
        let summaryTitle = NSTextField(labelWithString: "今天减少的手动切换")
        summaryTitle.font = .systemFont(ofSize: 13, weight: .medium)
        summaryTitle.textColor = .secondaryLabelColor
        todayCountLabel.font = .monospacedDigitSystemFont(ofSize: 44, weight: .bold)
        let summaryDetail = NSTextField(labelWithString: "这些操作已由 InputSwitch 自动完成")
        summaryDetail.textColor = .secondaryLabelColor
        summary.addArrangedSubview(summaryTitle)
        summary.addArrangedSubview(todayCountLabel)
        summary.addArrangedSubview(summaryDetail)

        let summaryIcon = NSImageView()
        summaryIcon.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "自动切换成功")
        summaryIcon.contentTintColor = .controlAccentColor
        summaryIcon.widthAnchor.constraint(equalToConstant: 38).isActive = true
        summaryIcon.heightAnchor.constraint(equalToConstant: 38).isActive = true
        let summaryContent = NSStackView(views: [summaryIcon, summary])
        summaryContent.orientation = .horizontal
        summaryContent.alignment = .centerY
        summaryContent.spacing = 16
        let summaryCard = card(for: summaryContent)

        yearControl.target = self
        yearControl.action = #selector(changeYear)
        yearControl.setAccessibilityLabel("年份")
        chartTitleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        let chartHeader = NSStackView(views: [chartTitleLabel, NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1)), yearControl])
        chartHeader.orientation = .horizontal
        chartView.heightAnchor.constraint(equalTo: chartView.widthAnchor, multiplier: 0.23).isActive = true
        let chartSection = NSStackView(views: [chartHeader, chartView])
        chartSection.orientation = .vertical
        chartSection.spacing = 12
        chartSection.alignment = .leading
        chartView.widthAnchor.constraint(equalTo: chartSection.widthAnchor).isActive = true
        let chartCard = card(for: chartSection)

        appsStack.orientation = .vertical
        appsStack.spacing = 12
        recentStack.orientation = .vertical
        recentStack.spacing = 10
        let appsSection = NSStackView(views: [sectionTitle("高频 App"), appsStack])
        appsSection.orientation = .vertical
        appsSection.alignment = .leading
        appsSection.spacing = 14
        let recentSection = NSStackView(views: [sectionTitle("最近切换"), recentStack])
        recentSection.orientation = .vertical
        recentSection.alignment = .leading
        recentSection.spacing = 14
        appsStack.widthAnchor.constraint(equalTo: appsSection.widthAnchor).isActive = true
        recentStack.widthAnchor.constraint(equalTo: recentSection.widthAnchor).isActive = true

        let appsCard = card(for: appsSection)
        let recentCard = card(for: recentSection)
        let lowerSection = NSStackView(views: [appsCard, recentCard])
        appsCard.heightAnchor.constraint(equalTo: recentCard.heightAnchor).isActive = true
        lowerSection.orientation = .horizontal
        lowerSection.alignment = .top
        lowerSection.distribution = .fillEqually
        lowerSection.spacing = 16

        configureEmptyView()
        errorLabel.textColor = .systemRed

        let privacyLabel = NSTextField(labelWithString: "记录仅保存在本机，不包含输入内容；分享由你主动发起")
        privacyLabel.textColor = .secondaryLabelColor
        privacyLabel.font = .systemFont(ofSize: 11)
        let clearButton = NSButton(title: "清空统计", target: self, action: #selector(clearStatistics))
        clearButton.bezelStyle = .rounded
        clearButton.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
        clearButton.imagePosition = .imageLeading
        clearButton.imageScaling = .scaleProportionallyDown
        clearButton.font = .systemFont(ofSize: 13, weight: .medium)
        clearButton.contentTintColor = .systemRed
        let footer = NSStackView(views: [privacyLabel, NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1)), clearButton])
        footer.orientation = .horizontal

        contentStack = FlippedStackView(views: [header, summaryCard, chartCard, lowerSection, emptyView, errorLabel, footer])
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 18
        contentStack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 24, right: 24)
        dataSections = [summaryCard, chartCard, lowerSection, footer]

        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.documentView = contentStack
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        scrollView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        contentStack.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor).isActive = true
        contentStack.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor).isActive = true
        contentStack.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor).isActive = true
        for section in [header, summaryCard, chartCard, lowerSection, emptyView, footer] {
            section.widthAnchor.constraint(equalTo: contentStack.widthAnchor, constant: -48).isActive = true
        }
    }

    private func configureEmptyView() {
        let imageView = NSImageView()
        imageView.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)
        imageView.contentTintColor = .secondaryLabelColor
        imageView.widthAnchor.constraint(equalToConstant: 36).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 36).isActive = true
        let title = NSTextField(labelWithString: "还没有切换记录")
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        let detail = NSTextField(labelWithString: "完成一次自动切换后，这里会显示真实记录")
        detail.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [imageView, title, detail])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        emptyView.addSubview(stack)
        stack.centerXAnchor.constraint(equalTo: emptyView.centerXAnchor).isActive = true
        stack.centerYAnchor.constraint(equalTo: emptyView.centerYAnchor).isActive = true
        emptyView.heightAnchor.constraint(equalToConstant: 260).isActive = true
    }

    private func bindState() {
        store.$events.sink { [weak self] _ in
            guard self?.isViewLoaded == true, self?.view.window?.isVisible == true else { return }
            self?.updateStatistics()
        }.store(in: &cancellables)
        store.$errorMessage.sink { [weak self] message in
            self?.errorLabel.stringValue = message ?? ""
        }.store(in: &cancellables)
    }

    private func updateStatistics() {
        let events = store.events
        let now = Date()
        let isEmpty = events.isEmpty
        emptyView.isHidden = !isEmpty
        dataSections.forEach { $0.isHidden = isEmpty }
        shareButton.isEnabled = !isEmpty
        todayCountLabel.stringValue = String(StatisticsAggregator.todayCount(events: events, now: now))
        todayCountLabel.setAccessibilityLabel("今天减少的手动切换次数")

        updateYearChoices(events: events, now: now)
        let year = Int(yearControl.titleOfSelectedItem ?? "") ?? Calendar.current.component(.year, from: now)
        let entries = entriesForYear(year, events: events)
        chartView.entries = entries
        chartTitleLabel.stringValue = "\(year) 年共 \(entries.reduce(0) { $0 + $1.count }) 次切换"
        updateApps(StatisticsAggregator.topApps(events: events, limit: 5))
        updateRecent(events.sorted { $0.timestamp > $1.timestamp }.prefix(6))
    }

    private func updateApps(_ usages: [AppUsage]) {
        removeRows(from: appsStack)
        let maximum = usages.map(\.count).max() ?? 1
        for usage in usages {
            let icon = appIcon(bundleID: usage.bundleID, size: 22)
            let name = NSTextField(labelWithString: usage.appName)
            name.lineBreakMode = .byTruncatingTail
            name.widthAnchor.constraint(equalToConstant: 130).isActive = true
            let bar = usageBar(count: usage.count, maximum: maximum)
            let count = NSTextField(labelWithString: "\(usage.count) 次")
            count.alignment = .right
            count.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            count.widthAnchor.constraint(equalToConstant: 48).isActive = true
            let row = NSStackView(views: [icon, name, bar, count])
            row.orientation = .horizontal
            row.spacing = 8
            row.edgeInsets = NSEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
            appsStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: appsStack.widthAnchor).isActive = true
        }
    }

    private func updateRecent(_ events: ArraySlice<SwitchEvent>) {
        removeRows(from: recentStack)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        for event in events {
            let time = NSTextField(labelWithString: formatter.string(from: event.timestamp))
            time.textColor = .secondaryLabelColor
            time.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            time.widthAnchor.constraint(equalToConstant: 42).isActive = true
            let icon = appIcon(bundleID: event.bundleID, size: 20)
            let detail = NSTextField(labelWithString: "\(event.appName) → \(event.inputSourceName)")
            detail.lineBreakMode = .byTruncatingTail
            let row = NSStackView(views: [time, icon, detail])
            row.orientation = .horizontal
            row.spacing = 8
            recentStack.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: recentStack.widthAnchor).isActive = true
        }
    }

    private func usageBar(count: Int, maximum: Int) -> NSView {
        let track = NSView()
        track.wantsLayer = true
        track.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
        track.layer?.cornerRadius = 3
        track.heightAnchor.constraint(equalToConstant: 6).isActive = true

        let fill = NSView()
        fill.wantsLayer = true
        fill.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        fill.layer?.cornerRadius = 3
        fill.translatesAutoresizingMaskIntoConstraints = false
        track.addSubview(fill)
        NSLayoutConstraint.activate([
            fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            fill.topAnchor.constraint(equalTo: track.topAnchor),
            fill.bottomAnchor.constraint(equalTo: track.bottomAnchor),
            fill.widthAnchor.constraint(equalTo: track.widthAnchor, multiplier: CGFloat(count) / CGFloat(maximum))
        ])
        return track
    }

    private func appIcon(bundleID: String, size: CGFloat) -> NSImageView {
        let imageView = NSImageView()
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            imageView.image = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            imageView.image = NSImage(systemSymbolName: "app", accessibilityDescription: nil)
        }
        imageView.widthAnchor.constraint(equalToConstant: size).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: size).isActive = true
        return imageView
    }

    private func card(for content: NSView) -> CardView {
        let card = CardView()
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        return card
    }

    private func sectionTitle(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        return label
    }

    private func removeRows(from stack: NSStackView) {
        for row in stack.arrangedSubviews {
            stack.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
    }

    private func updateYearChoices(events: [SwitchEvent], now: Date) {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: now)
        let selected = yearControl.titleOfSelectedItem
        var years = Set(events.map { calendar.component(.year, from: $0.timestamp) })
        years.insert(currentYear)
        let titles = years.sorted(by: >).map(String.init)
        if yearControl.itemTitles != titles {
            yearControl.removeAllItems()
            yearControl.addItems(withTitles: titles)
        }
        if let selected, titles.contains(selected) {
            yearControl.selectItem(withTitle: selected)
        } else {
            yearControl.selectItem(withTitle: String(currentYear))
        }
    }

    private func entriesForYear(_ year: Int, events: [SwitchEvent]) -> [DailyCount] {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1
        guard let start = calendar.date(from: components),
              let nextYear = calendar.date(byAdding: .year, value: 1, to: start),
              let end = calendar.date(byAdding: .day, value: -1, to: nextYear),
              let days = calendar.dateComponents([.day], from: start, to: nextYear).day else {
            return []
        }
        return StatisticsAggregator.dailyCounts(events: events, endingOn: end, days: days, calendar: calendar)
    }

    @objc private func changeYear() {
        updateStatistics()
    }

    @objc private func share() {
        guard let window = view.window else { return }
        let scale = window.backingScaleFactor
        let bounds = contentStack.bounds
        let width = Int(bounds.width * scale)
        let height = Int(bounds.height * scale)
        guard width > 0, height > 0,
              let representation = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: width,
                pixelsHigh: height,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
              ) else { return }
        contentStack.cacheDisplay(in: bounds, to: representation)
        let image = NSImage(size: bounds.size)
        image.addRepresentation(representation)
        let picker = NSSharingServicePicker(items: [image])
        picker.show(relativeTo: shareButton.bounds, of: shareButton, preferredEdge: .minY)
    }

    @objc private func clearStatistics() {
        guard let window = view.window else { return }
        let alert = NSAlert()
        alert.messageText = "清空所有统计？"
        alert.informativeText = "此操作只删除切换记录，不影响规则，且无法撤销。"
        alert.addButton(withTitle: "清空")
        alert.addButton(withTitle: "取消")
        alert.beginSheetModal(for: window) { [weak self] response in
            if response == .alertFirstButtonReturn {
                self?.store.clear()
            }
        }
    }
}
