import AppKit
import Combine
import InputSwitchCore
import ServiceManagement

final class RulesViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private let store: RuleStore
    private let coordinator: SwitchCoordinator
    private let inputSources: CarbonInputSourceService
    private var cancellables = Set<AnyCancellable>()
    private var availableSources: [InputSourceInfo] = []
    private var launchError: String? {
        didSet { updateError() }
    }

    private let stateLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let errorLabel = NSTextField(labelWithString: "")
    private let emptyLabel = NSTextField(labelWithString: "尚未配置规则，请点击“添加规则”")
    private let tableView = NSTableView()
    private let pauseButton = NSButton()
    private let launchCheckbox = NSButton(checkboxWithTitle: "登录时启动", target: nil, action: nil)

    init(store: RuleStore, coordinator: SwitchCoordinator, inputSources: CarbonInputSourceService) {
        self.store = store
        self.coordinator = coordinator
        self.inputSources = inputSources
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 380))
        configureTable()
        configureLayout()
        bindState()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refreshInputSources()
        launchCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        store.rules.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let rule = store.rules[row]
        if tableColumn?.identifier.rawValue == "App" {
            return makeAppCell(for: rule)
        }
        return makeInputSourceCell(for: rule)
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = NSTableRowView()
        rowView.backgroundColor = row.isMultiple(of: 2)
            ? NSColor.labelColor.withAlphaComponent(0.035)
            : .clear
        return rowView
    }

    private func makeAppCell(for rule: Rule) -> NSTableCellView {
        let cell = NSTableCellView()
        let iconView = NSImageView()
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: rule.bundleID) {
            iconView.image = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            iconView.image = NSImage(systemSymbolName: "app", accessibilityDescription: nil)
        }
        iconView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 20).isActive = true

        let textField = NSTextField(labelWithString: rule.appName)
        textField.lineBreakMode = .byTruncatingMiddle
        cell.textField = textField

        let content = NSStackView(views: [iconView, textField])
        content.orientation = .horizontal
        content.alignment = .centerY
        content.spacing = 8
        content.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            content.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -8),
            content.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }

    private func makeInputSourceCell(for rule: Rule) -> NSTableCellView {
        let cell = NSTableCellView()
        let popUp = NSPopUpButton(frame: .zero, pullsDown: false)
        popUp.font = .systemFont(ofSize: 13)
        popUp.target = self
        popUp.action = #selector(changeInputSource(_:))
        popUp.setAccessibilityLabel("\(rule.appName) 的输入法")

        for source in availableSources {
            popUp.addItem(withTitle: source.name)
            popUp.lastItem?.representedObject = source.id
        }
        if let index = availableSources.firstIndex(where: { $0.id == rule.inputSourceID }) {
            popUp.selectItem(at: index)
        } else {
            popUp.addItem(withTitle: "\(rule.inputSourceID)（不可用）")
            popUp.lastItem?.representedObject = rule.inputSourceID
            popUp.selectItem(at: popUp.numberOfItems - 1)
        }

        popUp.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(popUp)
        NSLayoutConstraint.activate([
            popUp.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            popUp.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            popUp.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            popUp.heightAnchor.constraint(equalToConstant: 24)
        ])
        return cell
    }

    @objc private func changeInputSource(_ sender: NSPopUpButton) {
        let row = tableView.row(for: sender)
        guard row >= 0,
              let inputSourceID = sender.selectedItem?.representedObject as? String else {
            return
        }
        let rule = store.rules[row]
        store.save(Rule(
            bundleID: rule.bundleID,
            appName: rule.appName,
            inputSourceID: inputSourceID
        ))
    }

    private func configureTable() {
        let appColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("App"))
        appColumn.title = "应用"
        appColumn.width = 285
        tableView.addTableColumn(appColumn)

        let inputColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("InputSource"))
        inputColumn.title = "输入法"
        inputColumn.width = 190
        tableView.addTableColumn(inputColumn)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.rowHeight = 32
        tableView.doubleAction = #selector(editSelectedRule)
        tableView.target = self
    }

    private func configureLayout() {
        pauseButton.title = ""
        pauseButton.target = self
        pauseButton.action = #selector(togglePause)

        let top = NSStackView(views: [stateLabel, NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1)), pauseButton])
        top.orientation = .horizontal

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        errorLabel.textColor = .systemRed
        errorLabel.lineBreakMode = .byTruncatingTail
        emptyLabel.alignment = .center
        emptyLabel.textColor = .secondaryLabelColor

        let addButton = NSButton(title: "添加规则", target: self, action: #selector(addRule))
        let deleteButton = NSButton(title: "删除", target: self, action: #selector(deleteRule))
        launchCheckbox.target = self
        launchCheckbox.action = #selector(updateLaunchAtLogin)
        let bottom = NSStackView(views: [addButton, deleteButton, NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1)), launchCheckbox])
        bottom.orientation = .horizontal

        let stack = NSStackView(views: [top, scrollView, emptyLabel, statusLabel, errorLabel, bottom])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            top.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -32),
            scrollView.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -32),
            statusLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -32),
            bottom.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -32)
        ])
    }

    private func bindState() {
        store.$rules.sink { [weak self] rules in
            self?.tableView.reloadData()
            self?.emptyLabel.isHidden = !rules.isEmpty
        }.store(in: &cancellables)

        store.$isPaused.sink { [weak self] isPaused in
            self?.stateLabel.stringValue = isPaused ? "已暂停" : "自动切换中"
            self?.stateLabel.textColor = isPaused ? .systemOrange : .labelColor
            self?.pauseButton.title = isPaused ? "恢复" : "暂停"
        }.store(in: &cancellables)

        store.$errorMessage.sink { [weak self] _ in self?.updateError() }.store(in: &cancellables)
        coordinator.$status.sink { [weak self] status in
            self?.statusLabel.stringValue = status
            self?.updateStatusColor()
        }.store(in: &cancellables)
        coordinator.$hasError.sink { [weak self] _ in self?.updateStatusColor() }.store(in: &cancellables)
    }

    @objc private func addRule() {
        presentEditor(for: nil)
    }

    @objc private func editSelectedRule() {
        let row = tableView.clickedRow
        guard row >= 0 else { return }
        presentEditor(for: store.rules[row])
    }

    @objc private func deleteRule() {
        let row = tableView.selectedRow
        guard row >= 0 else { return }
        store.delete(id: store.rules[row].id)
    }

    @objc private func togglePause() {
        store.isPaused.toggle()
    }

    @objc private func updateLaunchAtLogin() {
        do {
            if launchCheckbox.state == .on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchError = nil
        } catch {
            launchError = "无法更新登录时启动设置"
        }
        launchCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    private func presentEditor(for rule: Rule?) {
        let editor = RuleEditorViewController(existingRule: rule, inputSources: inputSources) { [weak self] rule in
            self?.store.save(rule)
            self?.refreshInputSources()
        }
        presentAsSheet(editor)
    }

    private func refreshInputSources() {
        availableSources = inputSources.availableInputSources()
        tableView.reloadData()
    }

    private func updateStatusColor() {
        statusLabel.textColor = coordinator.hasError ? .systemOrange : .secondaryLabelColor
    }

    private func updateError() {
        errorLabel.stringValue = store.errorMessage ?? launchError ?? ""
    }
}
