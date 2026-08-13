import Foundation
import Testing

@testable import DropCore

/// 구 Flutter 앱의 `lib/core/utils/time_utils.dart` 동작을 그대로 옮긴 것.
/// (원본은 BRU-22 삭제 커밋 이전 git 히스토리에 있다.)
/// 두 앱이 병렬 운영되는 동안 같은 노트가 같은 문구로 보여야 한다.
@Suite("상대 시간 표기")
struct RelativeTimeFormatterTests {
    private let formatter = RelativeTimeFormatter(
        calendar: {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
            return calendar
        }()
    )

    /// 2026-08-12 14:30:00 KST
    private var now: Date {
        DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(identifier: "Asia/Seoul"),
            year: 2026, month: 8, day: 12, hour: 14, minute: 30
        ).date!
    }

    @Test("1분 미만은 초 단위로 표기한다")
    func secondsUnderOneMinute() {
        #expect(formatter.string(for: now.addingTimeInterval(-5), now: now) == "5초전")
        #expect(formatter.string(for: now.addingTimeInterval(-59), now: now) == "59초전")
    }

    @Test("1시간 미만은 분 단위로 표기한다")
    func minutesUnderOneHour() {
        #expect(formatter.string(for: now.addingTimeInterval(-60), now: now) == "1분전")
        #expect(formatter.string(for: now.addingTimeInterval(-59 * 60), now: now) == "59분전")
    }

    @Test("오늘이면 시:분을 두 자리로 붙인다")
    func todayShowsPaddedTime() {
        // 오늘 09:05 (현재로부터 5시간 25분 전)
        let today0905 = now.addingTimeInterval(-(5 * 3600 + 25 * 60))
        #expect(formatter.string(for: today0905, now: now) == "오늘 09:05")
    }

    @Test("어제면 어제 시:분으로 표기한다")
    func yesterdayShowsTime() {
        let yesterday2300 = now.addingTimeInterval(-(15 * 3600 + 30 * 60))
        #expect(formatter.string(for: yesterday2300, now: now) == "어제 23:00")
    }

    @Test("그 이전은 연. 월. 일. 로 표기한다")
    func olderShowsDate() {
        let twoDaysAgo = now.addingTimeInterval(-(2 * 24 * 3600))
        #expect(formatter.string(for: twoDaysAgo, now: now) == "2026. 8. 10.")
    }

    @Test("미래 시각은 0초전으로 떨어진다")
    func futureClampsToZero() {
        #expect(formatter.string(for: now.addingTimeInterval(30), now: now) == "0초전")
    }
}
