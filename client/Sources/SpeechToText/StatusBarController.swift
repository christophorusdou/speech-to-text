import AppKit

class StatusBarController {
    enum State {
        case idle, recording, transcribing, processing, error
    }

    var state: State = .idle {
        didSet { updateIcon() }
    }

    var onQuit: (() -> Void)?
    var onModelChanged: ((String) -> Void)?
    var onEditVocabulary: (() -> Void)?
    var onLLMToggled: ((Bool) -> Void)?

    private let statusItem: NSStatusItem
    private var modelMenu: NSMenu?
    private var promptItem: NSMenuItem?
    private var llmToggleItem: NSMenuItem?
    private var llmEndpointItem: NSMenuItem?

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

    func updatePromptDisplay(_ prompt: String) {
        if prompt.isEmpty {
            promptItem?.title = "Prompt: (none)"
        } else if prompt.count > 40 {
            promptItem?.title = "Prompt: \(String(prompt.prefix(40)))..."
        } else {
            promptItem?.title = "Prompt: \(prompt)"
        }
    }

    func updateLLMDisplay(enabled: Bool, endpoint: String) {
        llmToggleItem?.state = enabled ? .on : .off
        llmEndpointItem?.title = "LLM: \(endpoint)"
    }

    private func updateIcon() {
        let title: String
        switch state {
        case .idle:        title = "\u{1F399}"  // 🎙
        case .recording:   title = "\u{1F534}"  // 🔴
        case .transcribing: title = "\u{23F3}"  // ⏳
        case .processing:  title = "\u{2699}"   // ⚙
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

        // Vocabulary prompt
        let pItem = NSMenuItem(title: "Prompt: (none)", action: nil, keyEquivalent: "")
        pItem.isEnabled = false
        menu.addItem(pItem)
        self.promptItem = pItem

        let editVocabItem = NSMenuItem(title: "Edit Vocabulary...", action: #selector(editVocabularyClicked), keyEquivalent: "")
        editVocabItem.target = self
        menu.addItem(editVocabItem)

        menu.addItem(.separator())

        // LLM post-processing
        let llmToggle = NSMenuItem(title: "LLM Post-Processing", action: #selector(llmToggleClicked), keyEquivalent: "")
        llmToggle.target = self
        llmToggle.state = .off
        menu.addItem(llmToggle)
        self.llmToggleItem = llmToggle

        let llmEp = NSMenuItem(title: "LLM: http://localhost:11434", action: nil, keyEquivalent: "")
        llmEp.isEnabled = false
        menu.addItem(llmEp)
        self.llmEndpointItem = llmEp

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
        modelMenu?.items.forEach { $0.state = .off }
        sender.state = .on
        onModelChanged?(model)
    }

    @objc private func editVocabularyClicked() {
        onEditVocabulary?()
    }

    @objc private func llmToggleClicked() {
        let newState = llmToggleItem?.state != .on
        llmToggleItem?.state = newState ? .on : .off
        onLLMToggled?(newState)
    }

    @objc private func quitClicked() {
        onQuit?()
    }
}
