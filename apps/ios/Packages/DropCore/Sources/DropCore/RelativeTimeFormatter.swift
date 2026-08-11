import Foundation

/// 노트 목록에 붙는 상대 시간 문구를 만든다.
///
/// Flutter 앱(`lib/core/utils/time_utils.dart`)과 문구가 1:1로 같아야 한다 —
/// 네이티브와 Flutter 앱이 같은 데이터를 병렬로 보여주는 기간이 있기 때문이다.
public struct RelativeTimeFormatter: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func string(for date: Date, now: Date = Date()) -> String {
        let elapsed = max(0, now.timeIntervalSince(date))

        let seconds = Int(elapsed)
        if seconds < 60 { return "\(seconds)초전" }

        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)분전" }

        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: now)

        if day == today { return "오늘 \(clockTime(of: date))" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), day == yesterday {
            return "어제 \(clockTime(of: date))"
        }

        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year!). \(parts.month!). \(parts.day!)."
    }

    private func clockTime(of date: Date) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour!, parts.minute!)
    }
}
