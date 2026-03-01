import AppKit

class StatusBarController {
    enum State {
        case idle, recording, transcribing, error
    }

    var state: State = .idle {
        didSet { updateIcon() }
    }

    var onQuit: (() -> Void)?
    var onModelChanged: ((String) -> Void)?

    private let statusItem: NSStatusItem
    private var modelMenu: NSMenu?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()
        buildMenu()
    }

    func setAvailableModels(_ models: [String], current: String) {
        modelMenu?.removeAllItems()
        for model in models {
            let item = NSMenuItem(title: model, action: #selector(modelSelected(_:)), keyEquivalent: "")
            item.target = self
            item.state = (model == current) ? .on : .off
            modelMenu?.addItem(item)
        }
    }

    private func updateIcon() {
        let title: String
        switch state {
        case .idle:        title = "\u{1F399}"  // 🎙
        case .recording:   title = "\u{1F534}"  // 🔴
        case .transcribing: title = "\u{23F3}"  // ⏳
        case .error:       title = "\u{26A0}"   // ⚠
        }
        statusItem.button?.title = title
    }

    private func buildMenu() {
        let menu = NSMenu()

        let hotkeyItem = NSMenuItem(title: "Hold \u{2318}\u{21E7}Space to record", action: nil, keyEquivalent: "")
        hotkeyItem.isEnabled = false
        menu.addItem(hotkeyItem)

        let endpointItem = NSMenuItem(title: "Endpoint: \(TranscriptionService.endpoint)", action: nil, keyEquivalent: "")
        endpointItem.isEnabled = false
        menu.addItem(endpointItem)

        menu.addItem(.separator())

        // Model submenu
        let modelSubmenu = NSMenu()
        self.modelMenu = modelSubmenu
        let modelItem = NSMenuItem(title: "Model", action: nil, keyEquivalent: "")
        modelItem.submenu = modelSubmenu
        menu.addItem(modelItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitClicked), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func modelSelected(_ sender: NSMenuItem) {
        let model = sender.title
        // Update checkmarks
        modelMenu?.items.forEach { $0.state = .off }
        sender.state = .on
        onModelChanged?(model)
    }

    @objc private func quitClicked() {
        onQuit?()
    }
}
