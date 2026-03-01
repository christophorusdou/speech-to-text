import AppKit

class StatusBarController {
    enum State {
        case idle, recording, transcribing, error
    }

    var state: State = .idle {
        didSet { updateIcon() }
    }

    var onQuit: (() -> Void)?

    private let statusItem: NSStatusItem

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()
        buildMenu()
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

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitClicked), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func quitClicked() {
        onQuit?()
    }
}
