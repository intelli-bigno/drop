import Foundation

/// 파싱한 노트 본문.
///
/// **`source`는 넣은 문자열 그대로다.** 이 타입은 렌더링을 위한 읽기 전용 표현이고,
/// 저장 경로와는 아무 관계가 없다 — 열람만 했는데 본문이 달라지는 일(BRU-66)을
/// 구조적으로 막으려면 "원문은 늘 여기 그대로 있다"가 타입에 드러나야 한다.
public struct MarkdownDocument: Equatable, Sendable {
    /// 파서에 들어온 문자열. 한 글자도 손대지 않는다.
    public let source: String
    public let blocks: [MarkdownBlock]

    public init(source: String, blocks: [MarkdownBlock]) {
        self.source = source
        self.blocks = blocks
    }

    public var isEmpty: Bool { blocks.isEmpty }
}

/// 블록 요소. 문단·제목·목록처럼 줄 단위로 갈리는 것들.
public indirect enum MarkdownBlock: Equatable, Sendable {
    case heading(level: Int, content: [MarkdownInline])
    case paragraph([MarkdownInline])
    /// 불릿·번호·체크박스가 한 덩어리로 들어온다. 항목마다 표식이 달려 있어
    /// 섞인 목록(`- 하나` 다음 `1. 둘`)도 한 블록으로 다룬다.
    case list([MarkdownListItem])
    case codeBlock(language: String?, code: String)
    case quote([MarkdownBlock])
    case thematicBreak
}

/// 목록 한 항목.
///
/// 중첩을 트리가 아니라 `indent` 값으로 평평하게 들고 있다 — 노트에 들어오는
/// 목록은 깊어야 두세 단이고, 트리로 만들면 파서와 렌더가 함께 복잡해진다.
public struct MarkdownListItem: Equatable, Sendable {
    /// 0이 최상위. 들여쓴 공백 두 칸이 한 단이다.
    public let indent: Int
    /// `nil`이면 불릿, 값이 있으면 순서 목록의 그 번호.
    public let ordinal: Int?
    /// `nil`이면 체크박스가 아닌 보통 항목.
    public let checked: Bool?
    public let content: [MarkdownInline]

    public init(indent: Int, ordinal: Int?, checked: Bool?, content: [MarkdownInline]) {
        self.indent = indent
        self.ordinal = ordinal
        self.checked = checked
        self.content = content
    }
}

/// 인라인 요소. 한 줄 안에서 글자에 걸리는 것들.
public indirect enum MarkdownInline: Equatable, Sendable {
    case text(String)
    case strong([MarkdownInline])
    case emphasis([MarkdownInline])
    case code(String)
    case link(content: [MarkdownInline], destination: String)
}
