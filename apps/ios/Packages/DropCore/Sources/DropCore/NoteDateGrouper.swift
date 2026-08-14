import Foundation

/// 목록 화면의 한 섹션. 화면은 이 배열을 그대로 그리기만 한다.
public struct NoteSection: Sendable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let notes: [Note]

    public init(id: String, title: String, notes: [Note]) {
        self.id = id
        self.title = title
        self.notes = notes
    }
}

/// 정렬된 노트 목록을 날짜 섹션으로 묶는다.
///
/// 순수 함수로 떼어 두어 시뮬레이터 없이 검증한다 — 자정·시간대 경계가
/// 화면 코드 안에 숨어 있으면 검증할 방법이 없다.
public struct NoteDateGrouper: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// 입력 순서를 그대로 유지한다 — 정렬은 `NoteAssembler.sorted`의 몫이고,
    /// 여기서 다시 정렬하면 두 규칙이 어긋날 때 화면이 조용히 달라진다.
    ///
    /// 고정한 노트는 날짜와 무관하게 맨 위로 뜨므로(정렬 규칙) 날짜에 섞지 않고
    /// 따로 한 섹션으로 모은다. 3개월 전에 만든 고정 노트가 "오늘" 아래
    /// 들어가는 일을 막는다.
    public func sections(for notes: [Note], now: Date = Date()) -> [NoteSection] {
        var sections: [NoteSection] = []

        let pinned = notes.filter(\.isPinned)
        if !pinned.isEmpty {
            sections.append(NoteSection(id: "pinned", title: "고정", notes: pinned))
        }

        let today = calendar.startOfDay(for: now)
        var order: [Date] = []
        var byDay: [Date: [Note]] = [:]

        for note in notes where !note.isPinned {
            // 미래 시각(기기 시계 어긋남 등)은 오늘로 접는다. RelativeTimeFormatter가
            // 미래를 "0초전"으로 접는 것과 같은 태도다.
            let day = min(calendar.startOfDay(for: note.createdAt), today)
            if byDay[day] == nil { order.append(day) }
            byDay[day, default: []].append(note)
        }

        for day in order {
            sections.append(
                NoteSection(
                    id: "day-\(day.timeIntervalSince1970)",
                    title: title(for: day, today: today),
                    notes: byDay[day] ?? []
                )
            )
        }

        return sections
    }

    private func title(for day: Date, today: Date) -> String {
        let days = calendar.dateComponents([.day], from: day, to: today).day ?? 0
        return switch days {
        case ..<1: "오늘"
        case 1: "어제"
        default: "\(days)일 전"
        }
    }
}
