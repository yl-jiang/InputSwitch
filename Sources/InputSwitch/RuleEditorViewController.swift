import AppKit
import InputSwitchCore

final class RuleEditorViewController: NSViewController {
    private struct AppInfo {
        let id: String
        let name: String
    }

    private let existingRule: Rule?
    private let inputSources: CarbonInputSourceService
    private let onSave: (Rule) -> Void
    private let appPopUp = NSPopUpButton()
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
        appPopUp.target = self
        appPopUp.action = #selector(selectionChanged)
        sourcePopUp.target = self
        sourcePopUp.action = #selector(selectionChanged)

        let appRow = choiceRow(label: "应用", popUp: appPopUp)
        let sourceRow = choiceRow(label: "输入法", popUp: sourcePopUp)

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

    private func choiceRow(label: String, popUp: NSPopUpButton) -> NSStackView {
        let labelField = NSTextField(labelWithString: label)
        labelField.alignment = .right
        labelField.widthAnchor.constraint(equalToConstant: 50).isActive = true
        popUp.widthAnchor.constraint(equalToConstant: 300).isActive = true
        let row = NSStackView(views: [labelField, popUp])
        row.orientation = .horizontal
        row.spacing = 12
        return row
    }

    private func loadChoices() {
        var seen = Set<String>()
        var apps = NSWorkspace.shared.runningApplications.compactMap { app -> AppInfo? in
            guard app.activationPolicy == .regular,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier,
                  let bundleID = app.bundleIdentifier,
                  let name = app.localizedName,
                  seen.insert(bundleID).inserted else {
                return nil
            }
            return AppInfo(id: bundleID, name: name)
        }
        if let existingRule, !apps.contains(where: { $0.id == existingRule.bundleID }) {
            apps.append(AppInfo(id: existingRule.bundleID, name: existingRule.appName))
        }
        apps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        var sources = inputSources.availableInputSources()
        if let existingRule, !sources.contains(where: { $0.id == existingRule.inputSourceID }) {
            sources.append(InputSourceInfo(
                id: existingRule.inputSourceID,
                name: "\(existingRule.inputSourceID)（不可用）"
            ))
        }

        appPopUp.addItem(withTitle: "请选择")
        for app in apps {
            appPopUp.addItem(withTitle: app.name)
            appPopUp.lastItem?.representedObject = app
        }
        sourcePopUp.addItem(withTitle: "请选择")
        for source in sources {
            sourcePopUp.addItem(withTitle: source.name)
            sourcePopUp.lastItem?.representedObject = source
        }

        if let existingRule {
            selectItem(in: appPopUp, id: existingRule.bundleID)
            selectItem(in: sourcePopUp, id: existingRule.inputSourceID)
        }
        selectionChanged()
    }

    private func selectItem(in popUp: NSPopUpButton, id: String) {
        for item in popUp.itemArray {
            if let app = item.representedObject as? AppInfo, app.id == id {
                popUp.select(item)
                return
            }
            if let source = item.representedObject as? InputSourceInfo, source.id == id {
                popUp.select(item)
                return
            }
        }
    }

    @objc private func selectionChanged() {
        saveButton.isEnabled = appPopUp.selectedItem?.representedObject != nil
            && sourcePopUp.selectedItem?.representedObject != nil
    }

    @objc private func save() {
        guard let app = appPopUp.selectedItem?.representedObject as? AppInfo,
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
