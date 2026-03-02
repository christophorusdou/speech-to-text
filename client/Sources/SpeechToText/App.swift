import AppKit
import ApplicationServices

@main
struct SpeechToTextApp {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController!
    private var hotkeyManager: HotkeyManager!
    private let audioRecorder = AudioRecorder()
    private let transcriptionService = TranscriptionService()
    private let pasteManager = PasteManager()
    private let llmPostProcessor = LLMPostProcessor()
    private var vocabularyWindowController: VocabularyWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()
        hotkeyManager = HotkeyManager(
            onKeyDown: { [weak self] in self?.startRecording() },
            onKeyUp: { [weak self] in self?.stopAndTranscribe() }
        )
        statusBarController.onQuit = {
            NSApplication.shared.terminate(nil)
        }
        statusBarController.onModelChanged = { [weak self] model in
            self?.transcriptionService.model = model
            UserDefaults.standard.set(model, forKey: "model")
        }
        statusBarController.onEditVocabulary = { [weak self] in
            self?.showVocabularyEditor()
        }
        statusBarController.onLLMToggled = { [weak self] enabled in
            self?.llmPostProcessor.isEnabled = enabled
        }

        // Initialize menu displays
        statusBarController.updatePromptDisplay(transcriptionService.prompt)
        statusBarController.updateLLMDisplay(
            enabled: llmPostProcessor.isEnabled,
            endpoint: llmPostProcessor.endpoint
        )

        // Check accessibility permission — prompts if not granted.
        // bundle.sh resets the TCC entry on each build to avoid stale signatures.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            NSLog("Accessibility permission not granted — paste simulation won't work")
        }

        // Request mic permission on launch
        audioRecorder.requestPermission { granted in
            if !granted {
                NSLog("Microphone permission not granted")
            }
        }

        // Fetch available models from server
        Task {
            let models = await transcriptionService.fetchModels()
            await MainActor.run {
                statusBarController.setAvailableModels(models, current: transcriptionService.model)
            }
        }
    }

    private func showVocabularyEditor() {
        if vocabularyWindowController == nil {
            vocabularyWindowController = VocabularyWindowController()
            vocabularyWindowController?.onSave = { [weak self] prompt in
                guard let self else { return }
                self.transcriptionService.prompt = prompt
                UserDefaults.standard.set(prompt, forKey: "prompt")
                self.statusBarController.updatePromptDisplay(prompt)
            }
        }
        vocabularyWindowController?.show(currentPrompt: transcriptionService.prompt)
    }

    private func startRecording() {
        guard audioRecorder.startRecording() else {
            statusBarController.state = .error
            return
        }
        statusBarController.state = .recording
    }

    private func stopAndTranscribe() {
        guard let audioURL = audioRecorder.stopRecording() else {
            statusBarController.state = .idle
            return
        }
        statusBarController.state = .transcribing

        Task {
            do {
                var text = try await transcriptionService.transcribe(fileURL: audioURL)

                if llmPostProcessor.isEnabled {
                    await MainActor.run {
                        statusBarController.state = .processing
                    }
                    do {
                        text = try await llmPostProcessor.process(text)
                    } catch {
                        NSLog("LLM post-processing failed, using original: \(error)")
                    }
                }

                let finalText = text
                await MainActor.run {
                    pasteManager.pasteText(finalText)
                    statusBarController.state = .idle
                }
            } catch {
                await MainActor.run {
                    NSLog("Transcription failed: \(error)")
                    statusBarController.state = .error
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                        self?.statusBarController.state = .idle
                    }
                }
            }
            try? FileManager.default.removeItem(at: audioURL)
        }
    }
}
