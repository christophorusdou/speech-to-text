import AppKit

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
                let text = try await transcriptionService.transcribe(fileURL: audioURL)
                await MainActor.run {
                    pasteManager.pasteText(text)
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
