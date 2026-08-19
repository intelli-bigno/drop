import Foundation

/// 작성 시트 툴바가 누를 수 있는 편집 동작.
public enum MarkdownEditingCommand: Equatable, Sendable, CaseIterable {
    case bold
    case italic
    /// 한 줄이면 인라인 코드, 여러 줄이면 펜스 코드블록.
    case code
    case link
    /// 누를 때마다 한 단계씩 깊어지고 여섯 단계 다음에 풀린다.
    case heading
    case bulletList
    case checkbox
    case quote
}

/// 명령을 적용한 결과. 새 글자와, 그 글자 위에서 커서가 있어야 할 자리.
public struct MarkdownEditingResult: Equatable, Sendable {
    public let text: String
    public let selection: NSRange

    public init(text: String, selection: NSRange) {
        self.text = text
        self.selection = selection
    }
}

/// 툴바 뒤의 계산. **화면이 아니라 여기가 정본이다.**
///
/// "무엇을 어디에 끼워 넣고 커서를 어디 두느냐"는 순수 함수로 떨어지고,
/// 그래야 시뮬레이터 없이 `make ios-test`로 잡힌다 (BRU-37).
///
/// 자리는 전부 UTF-16 기준이다 — `UITextView.selectedRange`가 쓰는 단위이고,
/// 글자 수로 세면 한글·이모지가 섞이는 순간 커서가 글자 가운데로 떨어진다.
public enum MarkdownEditor {
    public static func apply(
        _ command: MarkdownEditingCommand,
        to text: String,
        selection: NSRange
    ) -> MarkdownEditingResult {
        let source = text as NSString
        let range = clamp(selection, to: source.length)

        switch command {
        case .bold: return wrap(with: "**", in: source, range: range)
        case .italic: return wrap(with: "*", in: source, range: range)
        case .code: return applyCode(in: source, range: range)
        case .link: return applyLink(in: source, range: range)
        case .heading, .bulletList, .checkbox, .quote:
            return applyLinePrefix(command, in: source, range: range)
        }
    }

    private static func clamp(_ range: NSRange, to length: Int) -> NSRange {
        let location = min(max(range.location, 0), length)
        return NSRange(location: location, length: min(max(range.length, 0), length - location))
    }

    // MARK: - 감싸기

    /// 이미 감싸여 있으면 푼다 — 같은 버튼이 켜고 끄기 둘 다를 한다.
    private static func wrap(with marker: String, in source: NSString, range: NSRange) -> MarkdownEditingResult {
        let width = (marker as NSString).length

        guard range.length > 0 else {
            let text = source.replacingCharacters(in: range, with: marker + marker)
            return MarkdownEditingResult(
                text: text,
                selection: NSRange(location: range.location + width, length: 0)
            )
        }

        let selected = source.substring(with: range)

        // 기호까지 함께 고른 경우.
        if selected.hasPrefix(marker), selected.hasSuffix(marker), (selected as NSString).length >= width * 2 {
            let inner = (selected as NSString).substring(with: NSRange(
                location: width,
                length: (selected as NSString).length - width * 2
            ))
            return MarkdownEditingResult(
                text: source.replacingCharacters(in: range, with: inner),
                selection: NSRange(location: range.location, length: (inner as NSString).length)
            )
        }

        // 기호 안쪽만 고른 경우.
        let before = NSRange(location: range.location - width, length: width)
        let after = NSRange(location: NSMaxRange(range), length: width)
        if before.location >= 0, NSMaxRange(after) <= source.length,
           source.substring(with: before) == marker, source.substring(with: after) == marker
        {
            let stripped = NSMutableString(string: source)
            stripped.replaceCharacters(in: after, with: "")
            stripped.replaceCharacters(in: before, with: "")
            return MarkdownEditingResult(
                text: stripped as String,
                selection: NSRange(location: range.location - width, length: range.length)
            )
        }

        return MarkdownEditingResult(
            text: source.replacingCharacters(in: range, with: marker + selected + marker),
            selection: NSRange(location: range.location + width, length: range.length)
        )
    }

    // MARK: - 코드

    /// 여러 줄에 백틱 하나를 두르면 렌더가 깨진다 — 그때는 펜스가 답이다.
    private static func applyCode(in source: NSString, range: NSRange) -> MarkdownEditingResult {
        let selected = source.substring(with: range)
        guard selected.contains("\n") else { return wrap(with: "`", in: source, range: range) }

        let fenced = "```\n" + selected + "\n```"
        return MarkdownEditingResult(
            text: source.replacingCharacters(in: range, with: fenced),
            selection: NSRange(location: range.location + 4, length: (selected as NSString).length)
        )
    }

    // MARK: - 링크

    /// 채울 자리를 골라 둔 채로 넘긴다 — 모바일에서 커서를 다시 찍는 것이 가장 번거롭다.
    private static func applyLink(in source: NSString, range: NSRange) -> MarkdownEditingResult {
        let placeholder = "url"
        let width = (placeholder as NSString).length

        guard range.length > 0 else {
            let label = "텍스트"
            let inserted = "[" + label + "](" + placeholder + ")"
            return MarkdownEditingResult(
                text: source.replacingCharacters(in: range, with: inserted),
                selection: NSRange(location: range.location + 1, length: (label as NSString).length)
            )
        }

        let selected = source.substring(with: range)
        let inserted = "[" + selected + "](" + placeholder + ")"
        return MarkdownEditingResult(
            text: source.replacingCharacters(in: range, with: inserted),
            // `[선택](` 뒤 = 1 + 선택 + 2
            selection: NSRange(location: range.location + range.length + 3, length: width)
        )
    }

    // MARK: - 줄 앞머리

    private static func applyLinePrefix(
        _ command: MarkdownEditingCommand,
        in source: NSString,
        range: NSRange
    ) -> MarkdownEditingResult {
        let lines = lineRanges(in: source, covering: range)
        let bodies = lines.map { body(of: $0, in: source) }

        // 일부만 붙어 있을 때 "떼기"로 판정하면 나머지 줄이 영영 목록이 되지 못한다.
        let removes = !bodies.isEmpty && bodies.allSatisfy { hasPrefix(command, in: split($0).rest) }
        // 제목은 켜고 끄기가 아니라 단계 오르기다 — 첫 줄을 보고 목표 단계를 정한다.
        let headingLevel = bodies.first.map { (self.headingLevel(split($0).rest) + 1) % 7 } ?? 1

        let updated = NSMutableString(string: source)
        var deltaBeforeSelection = 0
        var totalDelta = 0

        for (line, body) in zip(lines, bodies).reversed() {
            let (indent, rest) = split(body)
            let newRest = transform(command, rest: rest, removes: removes, headingLevel: headingLevel)
            let newBody = indent + newRest
            let delta = (newBody as NSString).length - (body as NSString).length
            guard delta != 0 else { continue }
            updated.replaceCharacters(in: NSRange(location: line.location, length: (body as NSString).length), with: newBody)
            totalDelta += delta
            if line.location <= range.location { deltaBeforeSelection += delta }
        }

        return MarkdownEditingResult(
            text: updated as String,
            selection: NSRange(
                location: max(range.location + deltaBeforeSelection, 0),
                length: max(range.length + totalDelta - deltaBeforeSelection, 0)
            )
        )
    }

    /// 고른 범위가 스치는 줄 전부. 길이 0짜리 선택도 그 줄 하나는 잡아야 한다.
    private static func lineRanges(in source: NSString, covering range: NSRange) -> [NSRange] {
        guard source.length > 0 else { return [NSRange(location: 0, length: 0)] }

        let paragraph = source.lineRange(for: range)
        var ranges: [NSRange] = []
        var cursor = paragraph.location
        while cursor < NSMaxRange(paragraph) {
            let line = source.lineRange(for: NSRange(location: cursor, length: 0))
            ranges.append(line)
            cursor = NSMaxRange(line)
        }
        return ranges.isEmpty ? [NSRange(location: range.location, length: 0)] : ranges
    }

    /// 줄 범위에서 줄바꿈 문자를 뺀 알맹이.
    private static func body(of line: NSRange, in source: NSString) -> String {
        var text = line.length > 0 ? source.substring(with: line) : ""
        while text.hasSuffix("\n") || text.hasSuffix("\r") { text.removeLast() }
        return text
    }

    private static func split(_ body: String) -> (indent: String, rest: String) {
        let rest = body.drop { $0 == " " || $0 == "\t" }
        return (String(body.prefix(body.count - rest.count)), String(rest))
    }

    private static func transform(
        _ command: MarkdownEditingCommand,
        rest: String,
        removes: Bool,
        headingLevel target: Int
    ) -> String {
        let marker = listMarker(in: rest)

        switch command {
        case .heading:
            let stripped = strippingHeading(rest)
            return target == 0 ? stripped : String(repeating: "#", count: target) + " " + stripped

        case .bulletList:
            // 불릿을 떼면 체크칸까지 함께 떨어진다 — 표식만 남으면 아무 뜻도 없다.
            if removes { return String(rest.dropFirst(marker.total)) }
            return "- " + rest

        case .checkbox:
            if removes { return String(rest.dropFirst(marker.total)) }
            guard marker.bullet > 0 else { return "- [ ] " + rest }
            return String(rest.prefix(marker.bullet)) + "[ ] " + String(rest.dropFirst(marker.bullet))

        case .quote:
            if removes { return String(rest.dropFirst(quotePrefixLength(rest))) }
            return "> " + rest

        case .bold, .italic, .code, .link:
            return rest
        }
    }

    private static func hasPrefix(_ command: MarkdownEditingCommand, in rest: String) -> Bool {
        switch command {
        case .bulletList: listMarker(in: rest).bullet > 0
        case .checkbox: listMarker(in: rest).checkbox > 0
        case .quote: quotePrefixLength(rest) > 0
        default: false
        }
    }

    // MARK: - 앞머리 알아보기

    private struct ListMarker {
        /// `- ` 길이. 0이면 불릿이 없다.
        let bullet: Int
        /// `[ ] ` 길이. 0이면 체크칸이 없다.
        let checkbox: Int
        var total: Int { bullet + checkbox }
    }

    private static func listMarker(in rest: String) -> ListMarker {
        var cursor = Substring(rest)
        var bullet = 0

        if let first = cursor.first, "-*+".contains(first) {
            var probe = cursor.dropFirst()
            let spaces = probe.prefix { $0 == " " || $0 == "\t" }.count
            if spaces > 0 {
                bullet = 1 + spaces
                probe = probe.dropFirst(spaces)
                cursor = probe
            }
        }

        var checkbox = 0
        if bullet > 0, cursor.count >= 3, cursor.first == "[" {
            let head = Array(cursor.prefix(3))
            if head[2] == "]", head[1] == " " || head[1] == "x" || head[1] == "X" {
                let spaces = cursor.dropFirst(3).prefix { $0 == " " || $0 == "\t" }.count
                checkbox = 3 + spaces
            }
        }

        return ListMarker(bullet: bullet, checkbox: checkbox)
    }

    private static func quotePrefixLength(_ rest: String) -> Int {
        guard rest.first == ">" else { return 0 }
        return 1 + rest.dropFirst().prefix { $0 == " " || $0 == "\t" }.count
    }

    private static func headingLevel(_ rest: String) -> Int {
        let hashes = rest.prefix { $0 == "#" }.count
        guard (1 ... 6).contains(hashes) else { return 0 }
        let after = rest.dropFirst(hashes)
        guard after.isEmpty || after.first == " " else { return 0 }
        return hashes
    }

    private static func strippingHeading(_ rest: String) -> String {
        let level = headingLevel(rest)
        guard level > 0 else { return rest }
        return String(rest.dropFirst(level).drop { $0 == " " || $0 == "\t" })
    }
}
