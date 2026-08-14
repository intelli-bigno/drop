import Foundation
import Testing

@testable import DropCore

/// 목록을 날짜 섹션으로 묶는 순수 로직. 화면 없이 검증한다.
@Suite("노트 날짜 섹션")
struct NoteDateGrouperTests {
    private let timeZone = TimeZone(identifier: "Asia/Seoul")!

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private var grouper: NoteDateGrouper { NoteDateGrouper(calendar: calendar) }

    /// 2026-08-12 14:30:00 KST
    private var now: Date { date(year: 2026, month: 8, day: 12, hour: 14, minute: 30) }

    private func date(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: timeZone,
            year: year, month: month, day: day, hour: hour, minute: minute
        ).date!
    }

    private func note(_ id: String, createdAt: Date, isPinned: Bool = false) -> Note {
        Note(
            id: id,
            displayID: 0,
            content: id,
            createdAt: createdAt,
            updatedAt: createdAt,
            source: .mobile,
            isPinned: isPinned
        )
    }

    @Test("빈 목록은 섹션도 없다")
    func emptyProducesNoSections() {
        #expect(grouper.sections(for: [], now: now).isEmpty)
    }

    @Test("오늘·어제·N일 전으로 제목을 붙인다")
    func titlesByDayDistance() {
        let sections = grouper.sections(
            for: [
                note("오늘", createdAt: date(year: 2026, month: 8, day: 12, hour: 9)),
                note("어제", createdAt: date(year: 2026, month: 8, day: 11, hour: 23)),
                note("사흘전", createdAt: date(year: 2026, month: 8, day: 9, hour: 1)),
            ],
            now: now
        )

        #expect(sections.map(\.title) == ["오늘", "어제", "3일 전"])
        #expect(sections.map { $0.notes.map(\.id) } == [["오늘"], ["어제"], ["사흘전"]])
    }

    @Test("같은 날이면 자정을 사이에 두지 않는 한 한 섹션이다")
    func sameDayStaysTogether() {
        let sections = grouper.sections(
            for: [
                note("늦은밤", createdAt: date(year: 2026, month: 8, day: 12, hour: 23, minute: 59)),
                note("자정직후", createdAt: date(year: 2026, month: 8, day: 12, hour: 0, minute: 0)),
            ],
            now: now
        )

        #expect(sections.count == 1)
        #expect(sections[0].title == "오늘")
    }

    @Test("자정을 넘기면 1분 차이여도 다른 섹션이다")
    func midnightSplitsSections() {
        let sections = grouper.sections(
            for: [
                note("오늘00:00", createdAt: date(year: 2026, month: 8, day: 12, hour: 0, minute: 0)),
                note("어제23:59", createdAt: date(year: 2026, month: 8, day: 11, hour: 23, minute: 59)),
            ],
            now: now
        )

        #expect(sections.map(\.title) == ["오늘", "어제"])
    }

    @Test("시간대는 주입한 달력을 따른다")
    func groupingFollowsInjectedCalendar() {
        // KST 2026-08-12 08:00 = UTC 2026-08-11 23:00.
        // 서울 달력에서는 오늘, UTC 달력에서는 어제여야 한다.
        let morningInSeoul = date(year: 2026, month: 8, day: 12, hour: 8)

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!

        #expect(grouper.sections(for: [note("a", createdAt: morningInSeoul)], now: now)[0].title == "오늘")
        #expect(
            NoteDateGrouper(calendar: utc)
                .sections(for: [note("a", createdAt: morningInSeoul)], now: now)[0].title == "어제"
        )
    }

    @Test("미래 시각은 오늘로 접는다")
    func futureFoldsIntoToday() {
        let sections = grouper.sections(
            for: [note("미래", createdAt: now.addingTimeInterval(3 * 24 * 3600))],
            now: now
        )

        #expect(sections.map(\.title) == ["오늘"])
    }

    @Test("고정한 노트는 날짜와 무관하게 맨 위 한 섹션으로 모은다")
    func pinnedNotesGetTheirOwnSection() {
        let sections = grouper.sections(
            for: [
                note("고정-오래된", createdAt: date(year: 2026, month: 1, day: 2), isPinned: true),
                note("오늘", createdAt: date(year: 2026, month: 8, day: 12, hour: 9)),
            ],
            now: now
        )

        #expect(sections.map(\.title) == ["고정", "오늘"])
        #expect(sections[0].notes.map(\.id) == ["고정-오래된"])
    }

    @Test("섹션 id는 서로 다르다")
    func sectionIDsAreUnique() {
        let sections = grouper.sections(
            for: [
                note("고정", createdAt: now, isPinned: true),
                note("오늘", createdAt: now),
                note("어제", createdAt: date(year: 2026, month: 8, day: 11)),
            ],
            now: now
        )

        #expect(Set(sections.map(\.id)).count == sections.count)
    }
}
