import Foundation

/// 한 줄 안에서 글자에 걸리는 문법 — 굵게·기울임·인라인 코드·링크.
///
/// 블록 파서와 갈라 둔 이유는 규칙의 성격이 다르기 때문이다. 블록은 줄을 보고
/// 판단하면 끝나지만, 인라인은 "닫는 짝이 있느냐"를 앞뒤로 살펴야 하고
/// 짝이 없으면 **글자 그대로 남겨야 한다** — 쓰는 도중의 노트가 절반쯤 사라지면 안 된다.
struct MarkdownInlineParser: Sendable {
    /// 역슬래시로 글자 취급을 강제할 수 있는 기호.
    private static let escapable: Set<Character> = ["\\", "`", "*", "_", "[", "]", "(", ")", "#", "+", "-", ".", "!", ">", "~", "|", "{", "}"]

    func parse(_ text: String) -> [MarkdownInline] {
        parse(Array(text)[...])
    }

    private func parse(_ characters: ArraySlice<Character>) -> [MarkdownInline] {
        var nodes: [MarkdownInline] = []
        var pending = ""
        var index = characters.startIndex

        func flush() {
            guard !pending.isEmpty else { return }
            nodes.append(.text(pending))
            pending = ""
        }

        while index < characters.endIndex {
            let character = characters[index]

            switch character {
            case "\\":
                let next = characters.index(after: index)
                // 기호가 아닌 글자 앞의 역슬래시는 글자다 — 윈도우 경로가 사라지면 안 된다.
                if next < characters.endIndex, Self.escapable.contains(characters[next]) {
                    pending.append(characters[next])
                    index = characters.index(after: next)
                } else {
                    pending.append(character)
                    index = characters.index(after: index)
                }

            case "`":
                if let close = characters[characters.index(after: index)...].firstIndex(of: "`") {
                    flush()
                    nodes.append(.code(String(characters[characters.index(after: index) ..< close])))
                    index = characters.index(after: close)
                } else {
                    pending.append(character)
                    index = characters.index(after: index)
                }

            case "*", "_":
                if let (node, next) = emphasis(in: characters, at: index) {
                    flush()
                    nodes.append(node)
                    index = next
                } else {
                    pending.append(character)
                    index = characters.index(after: index)
                }

            case "[":
                if let (node, next) = link(in: characters, at: index) {
                    flush()
                    nodes.append(node)
                    index = next
                } else {
                    pending.append(character)
                    index = characters.index(after: index)
                }

            default:
                pending.append(character)
                index = characters.index(after: index)
            }
        }

        flush()
        return nodes
    }

    // MARK: - 강조

    private func emphasis(
        in characters: ArraySlice<Character>,
        at start: ArraySlice<Character>.Index
    ) -> (MarkdownInline, ArraySlice<Character>.Index)? {
        let marker = characters[start]
        let openingRun = run(of: marker, in: characters, from: start)
        let width = openingRun >= 2 ? 2 : 1

        // `_`는 단어 안에서 강조가 되지 않는다 — `snake_case_name`이 기울임이 되면
        // 코드 이름을 적은 노트가 통째로 뭉개진다.
        if marker == "_", start > characters.startIndex {
            let previous = characters[characters.index(before: start)]
            guard !previous.isLetter, !previous.isNumber else { return nil }
        }

        let contentStart = characters.index(start, offsetBy: width)
        guard contentStart < characters.endIndex else { return nil }
        guard let close = closingRun(of: marker, width: width, in: characters, from: contentStart) else { return nil }

        if marker == "_" {
            let after = characters.index(close, offsetBy: width)
            if after < characters.endIndex {
                let next = characters[after]
                guard !next.isLetter, !next.isNumber else { return nil }
            }
        }

        let content = parse(characters[contentStart ..< close])
        guard !content.isEmpty else { return nil }
        let node: MarkdownInline = width == 2 ? .strong(content) : .emphasis(content)
        return (node, characters.index(close, offsetBy: width))
    }

    /// 닫는 표식의 시작 위치.
    ///
    /// 표식이 세 개 이상 몰려 있으면(`***기울고***`) **뒤쪽을 닫는 짝으로 잡는다** —
    /// 앞쪽을 잡으면 안쪽 강조가 통째로 글자로 떨어진다.
    private func closingRun(
        of marker: Character,
        width: Int,
        in characters: ArraySlice<Character>,
        from start: ArraySlice<Character>.Index
    ) -> ArraySlice<Character>.Index? {
        var index = start
        while index < characters.endIndex {
            guard characters[index] == marker else {
                index = characters.index(after: index)
                continue
            }
            let length = run(of: marker, in: characters, from: index)
            if length >= width {
                return characters.index(index, offsetBy: length - width)
            }
            index = characters.index(index, offsetBy: length)
        }
        return nil
    }

    private func run(
        of marker: Character,
        in characters: ArraySlice<Character>,
        from start: ArraySlice<Character>.Index
    ) -> Int {
        var length = 0
        var index = start
        while index < characters.endIndex, characters[index] == marker {
            length += 1
            index = characters.index(after: index)
        }
        return length
    }

    // MARK: - 링크

    private func link(
        in characters: ArraySlice<Character>,
        at start: ArraySlice<Character>.Index
    ) -> (MarkdownInline, ArraySlice<Character>.Index)? {
        var depth = 0
        var index = start
        var labelEnd: ArraySlice<Character>.Index?

        while index < characters.endIndex {
            switch characters[index] {
            case "[": depth += 1
            case "]":
                depth -= 1
                if depth == 0 { labelEnd = index }
            default: break
            }
            if labelEnd != nil { break }
            index = characters.index(after: index)
        }

        guard let labelEnd else { return nil }
        let parenStart = characters.index(after: labelEnd)
        guard parenStart < characters.endIndex, characters[parenStart] == "(" else { return nil }
        guard let parenEnd = characters[parenStart...].firstIndex(of: ")") else { return nil }

        let inside = String(characters[characters.index(after: parenStart) ..< parenEnd])
        // `[글](주소 "제목")`의 제목은 화면에 쓸 데가 없다.
        let destination = inside.split(separator: " ", maxSplits: 1).first.map(String.init) ?? ""
        guard !destination.isEmpty else { return nil }

        let content = parse(characters[characters.index(after: start) ..< labelEnd])
        guard !content.isEmpty else { return nil }
        return (.link(content: content, destination: destination), characters.index(after: parenEnd))
    }
}
