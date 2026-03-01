import AVFoundation

class AudioRecorder {
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?

    func requestPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                completion(granted)
            }
        default:
            NSLog("Microphone permission denied. Grant access in System Settings > Privacy & Security > Microphone")
            completion(false)
        }
    }

    func startRecording() -> Bool {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.record()
            recordingURL = url
            return true
        } catch {
            NSLog("Failed to start recording: \(error)")
            return false
        }
    }

    func stopRecording() -> URL? {
        recorder?.stop()
        recorder = nil
        let url = recordingURL
        recordingURL = nil
        return url
    }
}
