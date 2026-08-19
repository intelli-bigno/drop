import Foundation

/// 노트 본문(평문 마크다운)을 렌더용 표현으로 옮긴다.
///
/// `AttributedString(markdown:)`을 쓰지 않은 이유는 하나다 — 그쪽은 인라인만 되고
/// 목록·체크박스·코드블록이 안 된다. 그리고 파서가 DropCore에 있어야
/// 시뮬레이터 없이 `make ios-test`로 문법별 검증이 돈다 (BRU-37).
///
/// **읽기 전용이다.** 입력 문자열은 어떤 경로로도 바뀌지 않으며 결과의 `source`에
/// 그대로 실려 나간다.
public struct MarkdownParser: Sendable {
    private let inlineParser = MarkdownInlineParser()

    public init() {}

    public func parse(_ source: String) -> MarkdownDocument {
        // 줄바꿈 표기만 통일한다. 원문은 `source`로 따로 들고 나간다.
        let normalized = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return MarkdownDocument(source: source, blocks: blocks(from: normalized.components(separatedBy: "\n")))
    }

    // MARK: - 블록

    private func blocks(from lines: [String]) -> [MarkdownBlock] {
        var result: [MarkdownBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]

            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                index += 1
                continue
            }

            if let fence = CodeFence(line) {
                let (block, next) = codeBlock(from: lines, opening: fence, at: index)
                result.append(block)
                index = next
                continue
            }

            if Self.isThematicBreak(line) {
                result.append(.thematicBreak)
                index += 1
                continue
            }

            if let (level, text) = Self.heading(line) {
                result.append(.heading(level: level, content: inlineParser.parse(text)))
                index += 1
                continue
            }

            if Self.quoteContent(line) != nil {
                var inner: [String] = []
                while index < lines.count, let stripped = Self.quoteContent(lines[index]) {
                    inner.append(stripped)
                    index += 1
                }
                result.append(.quote(blocks(from: inner)))
                continue
            }

            if Self.listItem(line) != nil {
                var items: [MarkdownListItem] = []
                while index < lines.count, let raw = Self.listItem(lines[index]) {
                    items.append(MarkdownListItem(
                        indent: raw.indent,
                        ordinal: raw.ordinal,
                        checked: raw.checked,
                        content: inlineParser.parse(raw.text)
                    ))
                    index += 1
                }
                result.append(.list(items))
                continue
            }

            var paragraph: [String] = []
            while index < lines.count, Self.continuesParagraph(lines[index]) {
                paragraph.append(lines[index])
                index += 1
            }
            result.append(.paragraph(inlineParser.parse(paragraph.joined(separator: "\n"))))
        }

        return result
    }

    /// 문단은 다른 블록이 시작되는 줄에서 끊긴다. 빈 줄도 끊는다.
    private static func continuesParagraph(_ line: String) -> Bool {
        guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard CodeFence(line) == nil else { return false }
        guard !isThematicBreak(line) else { return false }
        guard heading(line) == nil else { return false }
        guard quoteContent(line) == nil else { return false }
        return listItem(line) == nil
    }

    // MARK: - 코드블록

    private struct CodeFence {
        let character: Character
        let length: Int
        let language: String?

        init?(_ line: String) {
            var rest = Substring(line)
            var indent = 0
            while rest.first == " " {
                rest = rest.dropFirst()
                indent += 1
            }
            guard indent <= 3, let first = rest.first, first == "`" || first == "~" else { return nil }

            var length = 0
            while rest.first == first {
                rest = rest.dropFirst()
                length += 1
            }
            guard length >= 3 else { return nil }

            let info = rest.trimmingCharacters(in: .whitespaces)
            // 백틱 펜스의 정보 문자열에는 백틱이 들어갈 수 없다 — 인라인 코드와 헷갈린다.
            if first == "`", info.contains("`") { return nil }

            character = first
            self.length = length
            language = info.isEmpty ? nil : info
        }

        /// 이 줄이 이 펜스를 닫는가.
        func closes(_ line: String) -> Bool {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.count >= length else { return false }
            return trimmed.allSatisfy { $0 == character }
        }
    }

    /// 닫히지 않은 펜스는 남은 줄 전부를 코드로 삼는다 — 아직 쓰는 중에
    /// 미리보기를 켰다고 나머지 글이 사라지면 안 된다.
    private func codeBlock(
        from lines: [String],
        opening: CodeFence,
        at index: Int
    ) -> (MarkdownBlock, Int) {
        var body: [String] = []
        var cursor = index + 1
        while cursor < lines.count, !opening.closes(lines[cursor]) {
            body.append(lines[cursor])
            cursor += 1
        }
        let next = cursor < lines.count ? cursor + 1 : cursor
        return (.codeBlock(language: opening.language, code: body.joined(separator: "\n")), next)
    }

    // MARK: - 줄 판별

    private static func isThematicBreak(_ line: String) -> Bool {
        let stripped = line.filter { $0 != " " && $0 != "\t" }
        guard stripped.count >= 3, let first = stripped.first, "-*_".contains(first) else { return false }
        return stripped.allSatisfy { $0 == first }
    }

    /// `#`이 하나에서 여섯 개, 그 뒤에 공백이 붙어야 제목이다.
    /// 공백을 요구하지 않으면 DROP의 `#태그` 표기가 전부 제목이 된다.
    private static func heading(_ line: String) -> (level: Int, text: String)? {
        var rest = Substring(line)
        var indent = 0
        while rest.first == " " {
            rest = rest.dropFirst()
            indent += 1
        }
        guard indent <= 3 else { return nil }

        var level = 0
        while rest.first == "#" {
            rest = rest.dropFirst()
            level += 1
        }
        guard (1 ... 6).contains(level) else { return nil }
        guard rest.isEmpty || rest.first == " " else { return nil }

        var text = rest.trimmingCharacters(in: .whitespaces)
        // 닫는 `#`(`# 제목 #`)은 표기일 뿐 글자가 아니다.
        if text.hasSuffix("#") {
            var trailing = Substring(text)
            while trailing.last == "#" { trailing = trailing.dropLast() }
            if trailing.isEmpty || trailing.last == " " {
                text = trailing.trimmingCharacters(in: .whitespaces)
            }
        }
        return (level, text)
    }

    /// 인용 줄이면 `>` 표식을 뗀 나머지를 준다.
    private static func quoteContent(_ line: String) -> String? {
        var rest = Substring(line)
        var indent = 0
        while rest.first == " " {
            rest = rest.dropFirst()
            indent += 1
        }
        guard indent <= 3, rest.first == ">" else { return nil }
        rest = rest.dropFirst()
        if rest.first == " " { rest = rest.dropFirst() }
        return String(rest)
    }

    private struct RawListItem {
        let indent: Int
        let ordinal: Int?
        let checked: Bool?
        let text: String
    }

    private static func listItem(_ line: String) -> RawListItem? {
        var rest = Substring(line)
        var spaces = 0
        while let first = rest.first, first == " " || first == "\t" {
            spaces += first == "\t" ? 4 : 1
            rest = rest.dropFirst()
        }

        guard let marker = rest.first else { return nil }
        var ordinal: Int?

        if "-*+".contains(marker) {
            rest = rest.dropFirst()
        } else if marker.isNumber {
            var digits = ""
            while let first = rest.first, first.isNumber {
                digits.append(first)
                rest = rest.dropFirst()
            }
            guard let delimiter = rest.first, delimiter == "." || delimiter == ")" else { return nil }
            rest = rest.dropFirst()
            ordinal = Int(digits)
        } else {
            return nil
        }

        // 표식 뒤에는 공백이 오거나 줄이 끝나야 한다. 아니면 `-hello`가 목록이 된다.
        if let next = rest.first {
            guard next == " " || next == "\t" else { return nil }
            rest = rest.drop { $0 == " " || $0 == "\t" }
        }

        var checked: Bool?
        if rest.count >= 3, rest.first == "[" {
            let mark = rest[rest.index(rest.startIndex, offsetBy: 1)]
            let closing = rest[rest.index(rest.startIndex, offsetBy: 2)]
            if closing == "]" {
                if mark == " " { checked = false }
                if mark == "x" || mark == "X" { checked = true }
            }
            if checked != nil {
                rest = rest.dropFirst(3).drop { $0 == " " || $0 == "\t" }
            }
        }

        // 들여쓰기 두 칸이 한 단. 네 칸씩 쓰는 사람에게는 두 단으로 보이지만,
        // 어느 쪽이든 "안쪽"이라는 관계는 그대로 읽힌다.
        return RawListItem(indent: spaces / 2, ordinal: ordinal, checked: checked, text: String(rest))
    }
}
