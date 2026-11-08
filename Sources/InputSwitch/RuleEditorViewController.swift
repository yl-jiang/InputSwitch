import AppKit
import InputSwitchCore
import UniformTypeIdentifiers

final class RuleEditorViewController: NSViewController {
    private struct AppInfo {
        let id: String
        let name: String
    }

    private let existingRule: Rule?
    private let inputSources: CarbonInputSourceService
    private let onSave: (Rule) -> Void
    private var selectedApp: AppInfo?
    private let appButton = NSButton(title: "选择应用…", target: nil, action: nil)
    private let sourcePopUp = NSPopUpButton()
    private let saveButton = NSButton(title: "保存", target: nil, action: nil)

    init(existingRule: Rule?, inputSources: CarbonInputSourceService, onSave: @escaping (Rule) -> Void) {
        self.existingRule = existingRule
        self.inputSources = inputSources
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 170))
        configureLayout()
        loadChoices()
    }

    private func configureLayout() {
        appButton.target = self
        appButton.action = #selector(chooseApplication)
        appButton.setAccessibilityLabel("选择应用")
        sourcePopUp.target = self
        sourcePopUp.action = #selector(selectionChanged)

        let appRow = choiceRow(label: "应用", control: appButton)
        let sourceRow = choiceRow(label: "输入法", control: sourcePopUp)

        let cancelButton = NSButton(title: "取消", target: self, action: #selector(cancel))
        cancelButton.keyEquivalent = "\u{1b}"
        saveButton.target = self
        saveButton.action = #selector(save)
        saveButton.keyEquivalent = "\r"
        let buttons = NSStackView(views: [NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1)), cancelButton, saveButton])
        buttons.orientation = .horizontal

        let stack = NSStackView(views: [appRow, sourceRow, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            appRow.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -40),
            sourceRow.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -40),
            buttons.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -40)
        ])
    }

    private func choiceRow(label: String, control: NSControl) -> NSStackView {
        let labelField = NSTextField(labelWithString: label)
        labelField.alignment = .right
        labelField.widthAnchor.constraint(equalToConstant: 50).isActive = true
        control.widthAnchor.constraint(equalToConstant: 300).isActive = true
        let row = NSStackView(views: [labelField, control])
        row.orientation = .horizontal
        row.spacing = 12
        return row
    }

    private func loadChoices() {
        var sources = inputSources.availableInputSources()
        if let existingRule, !sources.contains(where: { $0.id == existingRule.inputSourceID }) {
            sources.append(InputSourceInfo(
                id: existingRule.inputSourceID,
                name: "\(existingRule.inputSourceID)（不可用）"
            ))
        }

        sourcePopUp.addItem(withTitle: "请选择")
        for source in sources {
            sourcePopUp.addItem(withTitle: source.name)
            sourcePopUp.lastItem?.representedObject = source
        }

        if let existingRule {
            selectedApp = AppInfo(id: existingRule.bundleID, name: existingRule.appName)
            appButton.title = existingRule.appName
            selectSource(id: existingRule.inputSourceID)
        }
        selectionChanged()
    }

    private func selectSource(id: String) {
        for item in sourcePopUp.itemArray {
            if let source = item.representedObject as? InputSourceInfo, source.id == id {
                sourcePopUp.select(item)
                return
            }
        }
    }

    @objc private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.prompt = "选择"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier,
              !bundleID.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "无法读取所选应用"
            alert.informativeText = "请选择有效的 macOS 应用。"
            alert.runModal()
            return
        }

        let name = (bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String)
            ?? (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? (bundle.localizedInfoDictionary?["CFBundleName"] as? String)
            ?? (bundle.infoDictionary?["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent
        selectedApp = AppInfo(id: bundleID, name: name)
        appButton.title = name
        selectionChanged()
    }

    @objc private func selectionChanged() {
        saveButton.isEnabled = selectedApp != nil
            && sourcePopUp.selectedItem?.representedObject != nil
    }

    @objc private func save() {
        guard let app = selectedApp,
              let source = sourcePopUp.selectedItem?.representedObject as? InputSourceInfo else {
            return
        }
        onSave(Rule(bundleID: app.id, appName: app.name, inputSourceID: source.id))
        dismiss(self)
    }

    @objc private func cancel() {
        dismiss(self)
    }
}
