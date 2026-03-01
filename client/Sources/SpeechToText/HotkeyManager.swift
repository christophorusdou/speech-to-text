import HotKey
import AppKit

class HotkeyManager {
    private var hotKey: HotKey?
    private let onKeyDown: () -> Void
    private let onKeyUp: () -> Void

    init(onKeyDown: @escaping () -> Void, onKeyUp: @escaping () -> Void) {
        self.onKeyDown = onKeyDown
        self.onKeyUp = onKeyUp
        setupHotkey()
    }

    private func setupHotkey() {
        // Command+Shift+Space
        hotKey = HotKey(key: .space, modifiers: [.command, .shift])

        hotKey?.keyDownHandler = { [weak self] in
            self?.onKeyDown()
        }

        hotKey?.keyUpHandler = { [weak self] in
            self?.onKeyUp()
        }
    }
}
