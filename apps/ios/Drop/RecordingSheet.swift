import DropCore
import DropUI
import SwiftUI

/// `widgets/recording_sheet.dart` 대응.
///
/// 전사(Whisper)는 부가 기능이다 — 실패해도 **오디오 노트 자체는 저장**한다.
/// 여기서 막으면 사용자가 방금 말한 내용을 통째로 잃는다.
struct RecordingSheet: View {
    let onComplete: (URL, String?) async -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dropContainer) private var container
    @State private var recorder = AudioRecorder()
    @State private var isFinishing = false
    @State private var transcriptionFailed = false

    var body: some View {
        VStack(spacing: DropTheme.Spacing.loose) {
            Text(timeText)
                .font(.system(size: 44, weight: .light, design: .rounded))
                .monospacedDigit()
                .padding(.top, DropTheme.Spacing.loose)

            WaveformView(levels: recorder.levels)
                .frame(height: 80)
                .padding(.horizontal, DropTheme.Spacing.loose)

            if recorder.state == .denied {
                VStack(spacing: DropTheme.Spacing.base) {
                    Text("마이크 권한이 꺼져 있습니다")
                        .font(.callout)
                    Button("설정 열기") { openSettings() }
                }
            }

            if transcriptionFailed {
                Text("전사에 실패했지만 녹음은 저장했습니다")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: DropTheme.Spacing.loose * 2) {
                Button("취소") {
                    _ = recorder.finish(discard: true)
                    dismiss()
                }
                .foregroundStyle(.secondary)

                Button {
                    Task { await toggleRecording() }
                } label: {
                    Image(systemName: recorder.state == .recording ? "pause.fill" : "mic.fill")
                        .font(.title)
                        .frame(width: 72, height: 72)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Circle())
                .disabled(recorder.state == .denied || isFinishing)

                Button("완료") {
                    Task { await finish() }
                }
                .fontWeight(.semibold)
                .disabled(recorder.state == .idle || isFinishing)
            }
            .padding(.bottom, DropTheme.Spacing.loose)
        }
        .task { await recorder.start() }
        .interactiveDismissDisabled(isFinishing)
    }

    private var timeText: String {
        let total = Int(recorder.duration)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func toggleRecording() async {
        switch recorder.state {
        case .recording: recorder.pause()
        case .paused: recorder.resume()
        case .idle: await recorder.start()
        case .denied: break
        }
    }

    private func finish() async {
        isFinishing = true
        defer { isFinishing = false }

        guard let url = recorder.finish() else {
            dismiss()
            return
        }

        var transcript: String?
        if let container {
            do {
                transcript = try await container.makeTranscriptionService().transcribe(audioAt: url)
            } catch {
                // 전사 실패는 녹음 저장을 막지 않는다.
                transcriptionFailed = true
            }
        }

        await onComplete(url, transcript)
        dismiss()
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
