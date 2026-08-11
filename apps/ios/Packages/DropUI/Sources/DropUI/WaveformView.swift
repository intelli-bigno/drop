import SwiftUI

/// `widgets/waveform_view.dart` 대응. 최근 레벨을 막대로 그린다.
public struct WaveformView: View {
    private let levels: [Float]

    public init(levels: [Float]) {
        self.levels = levels
    }

    public var body: some View {
        Canvas { context, size in
            guard !levels.isEmpty else { return }

            let barWidth: CGFloat = 3
            let gap: CGFloat = 2
            let maxBars = Int(size.width / (barWidth + gap))
            // 오래된 것부터 밀어내며 오른쪽 끝이 항상 "지금"이 되게 한다.
            let visible = levels.suffix(maxBars)

            for (index, level) in visible.enumerated() {
                let height = max(2, CGFloat(level) * size.height)
                let x = size.width - CGFloat(visible.count - index) * (barWidth + gap)
                let rect = CGRect(
                    x: x,
                    y: (size.height - height) / 2,
                    width: barWidth,
                    height: height
                )
                context.fill(Path(roundedRect: rect, cornerRadius: barWidth / 2), with: .color(.accentColor))
            }
        }
    }
}
