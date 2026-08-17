import Foundation

/// 목록 화면의 한 줄. 노트 하나와 그 노트를 어떻게 그릴지가 함께 담긴다.
///
/// 답글을 그리려면 노트만으로는 부족하다 — 몇 단 들여쓸지, 맥락으로 끌어온 것인지,
/// 부모를 잃은 것인지를 화면이 알아야 한다. 그 판단을 화면에 두면 검증할 수 없어
/// 여기서 미리 정해 내려보낸다.
public struct NoteRow: Sendable, Equatable, Identifiable {
    public let note: Note
    /// 들여쓰기 단수. 데이터상 깊이가 아니라 **그릴 깊이**다 (상한에서 멈춘다).
    public let depth: Int
    /// 필터·검색에 걸린 것이 아니라 자식의 맥락을 위해 끌어온 노트.
    public let isContextOnly: Bool
    /// 부모가 이 뷰에 없어 최상위로 올라온 답글. 독립 노트처럼 보이면 안 된다.
    public let isOrphanedReply: Bool

    public var id: String { note.id }

    public init(note: Note, depth: Int, isContextOnly: Bool = false, isOrphanedReply: Bool = false) {
        self.note = note
        self.depth = depth
        self.isContextOnly = isContextOnly
        self.isOrphanedReply = isOrphanedReply
    }
}

/// 평평한 노트 목록을 부모-자식으로 묶어 화면이 그대로 그릴 행 배열로 만든다.
///
/// 순수 함수로 떼어 두어 시뮬레이터 없이 검증한다 — 데스크톱은 이 로직이 화면
/// 컴포넌트(`NoteFeed.tsx`) 안에 있어 테스트가 없다. 같은 실수를 반복하지 않는다.
public enum NoteHierarchy {
    /// 화면이 그릴 기본 들여쓰기 상한. 좁은 화면에서 3단 이상 들여쓰면 본문 폭이 무너진다.
    public static let defaultMaxIndentDepth = 2

    /// - Parameters:
    ///   - visible: 필터·검색까지 통과해 **실제로 보여야 하는** 노트. 순서가 최상위 노트의 순서가 된다.
    ///   - context: 같은 뷰(활성/보관/휴지통)에 있는 노트 전부. 부모를 끌어올 후보다.
    ///     `visible`은 이 집합의 부분집합이어야 한다.
    ///   - maxIndentDepth: 들여쓰기 상한.
    ///
    /// 규칙:
    /// 1. 보이는 답글의 부모는 필터에 걸리지 않아도 **끌어온다** — 그러지 않으면 답글이
    ///    최상위로 튀어 어느 노트에 달린 것인지 알 수 없어진다.
    /// 2. 부모가 이 뷰에 아예 없으면(보관·휴지통에 있거나 지워졌으면) 답글을 버리지 않고
    ///    최상위로 올리되 `isOrphanedReply`로 표시한다. 버리면 노트가 조용히 사라진다.
    /// 3. 형제 답글은 오래된 것부터 — 데스크톱(`NoteFeed.tsx`)과 같은 규칙이다.
    public static func rows(
        visible: [Note],
        context: [Note],
        maxIndentDepth: Int = defaultMaxIndentDepth
    ) -> [NoteRow] {
        guard !visible.isEmpty else { return [] }

        // 같은 노트가 두 번 들어와도 행은 한 번만 나야 한다.
        var contextByID: [String: Note] = [:]
        var contextOrder: [String] = []
        for note in context where contextByID[note.id] == nil {
            contextByID[note.id] = note
            contextOrder.append(note.id)
        }

        var visibleIDs: Set<String> = []
        var visibleOrder: [String] = []
        for note in visible where !visibleIDs.contains(note.id) {
            visibleIDs.insert(note.id)
            visibleOrder.append(note.id)
            // visible이 context에 없을 수도 있다(호출자가 다른 집합을 넘긴 경우).
            // 그래도 노트를 잃지 않도록 여기서 채워 넣는다.
            if contextByID[note.id] == nil {
                contextByID[note.id] = note
                contextOrder.append(note.id)
            }
        }

        // 규칙 1 — 보이는 노트의 조상을 맥락으로 끌어온다.
        var included = visibleIDs
        for id in visibleOrder {
            var seen: Set<String> = [id]
            var current = contextByID[id]
            while let parentID = current?.parentID, let parent = contextByID[parentID] {
                // 망가진 데이터(자기 참조·순환)에서 멈추지 않으면 무한 루프가 된다.
                guard seen.insert(parent.id).inserted else { break }
                included.insert(parent.id)
                current = parent
            }
        }

        // 부모를 따라 올라가다 제자리로 돌아오는 노트(망가진 데이터)를 가려낸다.
        // 이것을 자식으로 붙이면 어느 뿌리에서도 닿지 못해 목록에서 조용히 사라진다.
        var loops: Set<String> = []
        for id in contextOrder where included.contains(id) {
            var seen: Set<String> = [id]
            var current = contextByID[id]
            while let parentID = current?.parentID, included.contains(parentID), let parent = contextByID[parentID] {
                guard seen.insert(parent.id).inserted else {
                    loops.insert(id)
                    break
                }
                current = parent
            }
        }

        var childrenByParentID: [String: [Note]] = [:]
        var rootIDs: [String] = []
        for id in contextOrder where included.contains(id) {
            guard let note = contextByID[id] else { continue }
            if let parentID = note.parentID, !loops.contains(id), included.contains(parentID) {
                childrenByParentID[parentID, default: []].append(note)
            } else {
                rootIDs.append(id)
            }
        }

        // 규칙 3 — 형제는 오래된 것부터.
        for (parentID, children) in childrenByParentID {
            childrenByParentID[parentID] = children.sorted { $0.createdAt < $1.createdAt }
        }

        var emitted: Set<String> = []
        var result: [NoteRow] = []

        func emit(_ note: Note, depth: Int) {
            guard emitted.insert(note.id).inserted else { return }
            result.append(
                NoteRow(
                    note: note,
                    depth: min(depth, maxIndentDepth),
                    isContextOnly: !visibleIDs.contains(note.id),
                    // 규칙 2 — 부모가 있는데 최상위로 나온 것은 부모를 잃은 답글이다.
                    isOrphanedReply: depth == 0 && note.parentID != nil && note.parentID != note.id
                )
            )
            for child in childrenByParentID[note.id] ?? [] {
                emit(child, depth: depth + 1)
            }
        }

        for id in rootIDs {
            guard let note = contextByID[id] else { continue }
            emit(note, depth: 0)
        }

        return result
    }
}
