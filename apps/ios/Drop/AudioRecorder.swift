import AVFoundation
import DropCore
import Observation

/// `data/services/audio_recorder_service.dart` 대응 (`record` 패키지 → AVFoundation).
///
/// 인코딩은 m4a/AAC로 고정한다 — Whisper Edge Function이 받는 형식이 Flutter 쪽과
/// 같아야 전사 결과가 갈리지 않는다.
@MainActor
@Observable
final class AudioRecorder: NSObject {
    enum State: Equatable {
        case idle
        case recording
        case paused
        case denied
    }

    private(set) var state: State = .idle
    private(set) var duration: TimeInterval = 0
    /// 파형용 최근 레벨(0...1).
    private(set) var levels: [Float] = []

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var fileURL: URL?

    func start() async {
        guard await ensurePermission() else {
            state = .denied
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.duckOthers])
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("drop-\(UUID().uuidString).m4a")
            let recorder = try AVAudioRecorder(url: url, settings: [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ])
            recorder.isMeteringEnabled = true
            recorder.delegate = self
            recorder.record()

            self.recorder = recorder
            self.fileURL = url
            levels = []
            duration = 0
            state = .recording
            startMetering()
        } catch {
            state = .idle
        }
    }

    func pause() {
        guard state == .recording else { return }
        recorder?.pause()
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        recorder?.record()
        state = .recording
    }

    /// 녹음을 끝내고 파일 위치를 돌려준다. 취소면 파일을 지우고 nil.
    func finish(discard: Bool = false) -> URL? {
        meterTimer?.invalidate()
        meterTimer = nil
        recorder?.stop()
        recorder = nil
        state = .idle
        // 다른 앱의 소리를 다시 살려 준다.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        guard let url = fileURL else { return nil }
        fileURL = nil

        if discard {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return url
    }

    private func ensurePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func startMetering() {
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sampleMeter() }
        }
    }

    private func sampleMeter() {
        guard let recorder, recorder.isRecording else { return }
        recorder.updateMeters()
        duration = recorder.currentTime

        // dB(-160...0)를 0...1로 편다. 그대로 쓰면 파형이 위쪽에 붙어 움직이지 않는다.
        let decibels = recorder.averagePower(forChannel: 0)
        let normalized = max(0, (decibels + 50) / 50)
        levels.append(normalized)
        if levels.count > 120 { levels.removeFirst(levels.count - 120) }
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    /// 전화가 오거나 다른 앱이 마이크를 가져가면 여기로 온다.
    /// 이미 녹음된 부분은 파일에 남아 있으므로 상태만 일시정지로 맞춘다.
    nonisolated func audioRecorderBeginInterruption(_ recorder: AVAudioRecorder) {
        Task { @MainActor in self.state = .paused }
    }
}
