import AppKit
import InputSwitchCore

final class MainViewController: NSViewController, NSToolbarDelegate {
    private enum Page {
        case rules
        case statistics
    }

    private let rulesViewController: RulesViewController
    private let statisticsViewController: StatisticsViewController
    private var currentViewController: NSViewController?
    private var pageSelector: NSSegmentedControl?

    init(store: RuleStore, coordinator: SwitchCoordinator, inputSources: CarbonInputSourceService, eventStore: SwitchEventStore) {
        rulesViewController = RulesViewController(store: store, coordinator: coordinator, inputSources: inputSources)
        statisticsViewController = StatisticsViewController(store: eventStore)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 760, height: 600))
        show(.rules)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard view.window?.toolbar == nil else { return }
        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        view.window?.toolbar = toolbar
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard itemIdentifier.rawValue == "PageSelector" else { return nil }
        let selector = NSSegmentedControl(labels: ["规则", "统计"], trackingMode: .selectOne, target: self, action: #selector(switchPage))
        selector.selectedSegment = currentViewController === statisticsViewController ? 1 : 0
        pageSelector = selector
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.view = selector
        return item
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, NSToolbarItem.Identifier("PageSelector")]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, NSToolbarItem.Identifier("PageSelector"), .flexibleSpace]
    }

    @objc private func switchPage() {
        show(pageSelector?.selectedSegment == 1 ? .statistics : .rules)
    }

    private func show(_ page: Page) {
        let next = page == .rules ? rulesViewController : statisticsViewController
        guard currentViewController !== next else { return }

        if let current = currentViewController {
            current.view.removeFromSuperview()
            current.removeFromParent()
        }

        addChild(next)
        next.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(next.view)
        NSLayoutConstraint.activate([
            next.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            next.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            next.view.topAnchor.constraint(equalTo: view.topAnchor),
            next.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        currentViewController = next
    }
}
