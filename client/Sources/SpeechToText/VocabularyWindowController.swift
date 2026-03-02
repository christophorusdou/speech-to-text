import AppKit

class VocabularyWindowController {
    var onSave: ((String) -> Void)?

    private var window: NSWindow?
    private var textView: NSTextView?

    func show(currentPrompt: String) {
        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Edit Vocabulary Prompt"
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 300, height: 180)

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]

        let label = NSTextField(labelWithString: "Words and phrases to bias recognition toward:")
        label.frame = NSRect(x: 16, y: 224, width: 388, height: 20)
        label.autoresizingMask = [.width, .minYMargin]
        contentView.addSubview(label)

        let scrollView = NSScrollView(frame: NSRect(x: 16, y: 52, width: 388, height: 168))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let textView = NSTextView(frame: scrollView.contentView.bounds)
        textView.autoresizingMask = [.width, .height]
        textView.isEditable = true
        textView.isRichText = false
        textView.font = .systemFont(ofSize: 13)
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.string = currentPrompt
        scrollView.documentView = textView
        contentView.addSubview(scrollView)
        self.textView = textView

        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveClicked))
        saveButton.frame = NSRect(x: 320, y: 12, width: 84, height: 28)
        saveButton.autoresizingMask = [.minXMargin, .maxYMargin]
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        contentView.addSubview(saveButton)

        window.contentView = contentView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    @objc private func saveClicked() {
        guard let text = textView?.string else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave?(trimmed)
        window?.close()
    }
}
