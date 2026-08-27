import 'markdown_document.dart';
import 'markdown_inline_parser.dart';

/// 노트 본문(평문 마크다운)을 렌더용 표현으로 옮긴다.
/// DropCore `MarkdownParser.swift` 대응.
///
/// **읽기 전용이다.** 입력 문자열은 어떤 경로로도 바뀌지 않으며 결과의 `source`에
/// 그대로 실려 나간다.
class MarkdownParser {
  static const _inlineParser = MarkdownInlineParser();

  const MarkdownParser();

  MarkdownDocument parse(String source) {
    // 줄바꿈 표기만 통일한다. 원문은 `source`로 따로 들고 나간다.
    final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    return MarkdownDocument(
      source: source,
      blocks: _blocks(normalized.split('\n')),
    );
  }

  // 블록

  List<MarkdownBlock> _blocks(List<String> lines) {
    final result = <MarkdownBlock>[];
    var index = 0;

    while (index < lines.length) {
      final line = lines[index];

      if (line.trim().isEmpty) {
        index += 1;
        continue;
      }

      final fence = _CodeFence.parse(line);
      if (fence != null) {
        final (block, next) = _codeBlock(lines, fence, index);
        result.add(block);
        index = next;
        continue;
      }

      if (_isThematicBreak(line)) {
        result.add(const MarkdownThematicBreak());
        index += 1;
        continue;
      }

      final heading = _heading(line);
      if (heading != null) {
        result.add(MarkdownHeading(
          level: heading.$1,
          content: _inlineParser.parse(heading.$2),
        ));
        index += 1;
        continue;
      }

      if (_quoteContent(line) != null) {
        final inner = <String>[];
        while (index < lines.length) {
          final stripped = _quoteContent(lines[index]);
          if (stripped == null) break;
          inner.add(stripped);
          index += 1;
        }
        result.add(MarkdownQuote(_blocks(inner)));
        continue;
      }

      if (_listItem(line) != null) {
        final items = <MarkdownListItem>[];
        while (index < lines.length) {
          final raw = _listItem(lines[index]);
          if (raw == null) break;
          items.add(MarkdownListItem(
            indent: raw.indent,
            ordinal: raw.ordinal,
            checked: raw.checked,
            content: _inlineParser.parse(raw.text),
          ));
          index += 1;
        }
        result.add(MarkdownList(items));
        continue;
      }

      final paragraph = <String>[];
      while (index < lines.length && _continuesParagraph(lines[index])) {
        paragraph.add(lines[index]);
        index += 1;
      }
      result.add(MarkdownParagraph(_inlineParser.parse(paragraph.join('\n'))));
    }

    return result;
  }

  /// 문단은 다른 블록이 시작되는 줄에서 끊긴다. 빈 줄도 끊는다.
  bool _continuesParagraph(String line) {
    if (line.trim().isEmpty) return false;
    if (_CodeFence.parse(line) != null) return false;
    if (_isThematicBreak(line)) return false;
    if (_heading(line) != null) return false;
    if (_quoteContent(line) != null) return false;
    return _listItem(line) == null;
  }

  /// 닫히지 않은 펜스는 남은 줄 전부를 코드로 삼는다 — 아직 쓰는 중에
  /// 미리보기를 켰다고 나머지 글이 사라지면 안 된다.
  (MarkdownBlock, int) _codeBlock(
    List<String> lines,
    _CodeFence opening,
    int index,
  ) {
    final body = <String>[];
    var cursor = index + 1;
    while (cursor < lines.length && !opening.closes(lines[cursor])) {
      body.add(lines[cursor]);
      cursor += 1;
    }
    final next = cursor < lines.length ? cursor + 1 : cursor;
    return (
      MarkdownCodeBlock(language: opening.language, code: body.join('\n')),
      next,
    );
  }

  // 줄 판별

  static bool _isThematicBreak(String line) {
    final stripped = line.replaceAll(' ', '').replaceAll('\t', '');
    if (stripped.length < 3) return false;
    final first = stripped[0];
    if (!'-*_'.contains(first)) return false;
    return stripped.split('').every((c) => c == first);
  }

  /// `#`이 하나에서 여섯 개, 그 뒤에 공백이 붙어야 제목이다.
  /// 공백을 요구하지 않으면 DROP의 `#태그` 표기가 전부 제목이 된다.
  static (int, String)? _heading(String line) {
    var cursor = 0;
    var indent = 0;
    while (cursor < line.length && line[cursor] == ' ') {
      cursor += 1;
      indent += 1;
    }
    if (indent > 3) return null;

    var level = 0;
    while (cursor < line.length && line[cursor] == '#') {
      cursor += 1;
      level += 1;
    }
    if (level < 1 || level > 6) return null;
    if (cursor < line.length && line[cursor] != ' ') return null;

    var text = line.substring(cursor).trim();
    // 닫는 `#`(`# 제목 #`)은 표기일 뿐 글자가 아니다.
    if (text.endsWith('#')) {
      var trailing = text;
      while (trailing.endsWith('#')) {
        trailing = trailing.substring(0, trailing.length - 1);
      }
      if (trailing.isEmpty || trailing.endsWith(' ')) {
        text = trailing.trim();
      }
    }
    return (level, text);
  }

  /// 인용 줄이면 `>` 표식을 뗀 나머지를 준다.
  static String? _quoteContent(String line) {
    var cursor = 0;
    var indent = 0;
    while (cursor < line.length && line[cursor] == ' ') {
      cursor += 1;
      indent += 1;
    }
    if (indent > 3) return null;
    if (cursor >= line.length || line[cursor] != '>') return null;
    cursor += 1;
    if (cursor < line.length && line[cursor] == ' ') cursor += 1;
    return line.substring(cursor);
  }

  static _RawListItem? _listItem(String line) {
    var cursor = 0;
    var spaces = 0;
    while (cursor < line.length && (line[cursor] == ' ' || line[cursor] == '\t')) {
      spaces += line[cursor] == '\t' ? 4 : 1;
      cursor += 1;
    }

    if (cursor >= line.length) return null;
    final marker = line[cursor];
    int? ordinal;

    if ('-*+'.contains(marker)) {
      cursor += 1;
    } else if (_isDigit(marker)) {
      var digits = '';
      while (cursor < line.length && _isDigit(line[cursor])) {
        digits += line[cursor];
        cursor += 1;
      }
      if (cursor >= line.length) return null;
      final delimiter = line[cursor];
      if (delimiter != '.' && delimiter != ')') return null;
      cursor += 1;
      ordinal = int.parse(digits);
    } else {
      return null;
    }

    // 표식 뒤에는 공백이 오거나 줄이 끝나야 한다. 아니면 `-hello`가 목록이 된다.
    if (cursor < line.length) {
      final next = line[cursor];
      if (next != ' ' && next != '\t') return null;
      while (
          cursor < line.length && (line[cursor] == ' ' || line[cursor] == '\t')) {
        cursor += 1;
      }
    }

    var rest = line.substring(cursor);
    bool? checked;
    if (rest.length >= 3 && rest[0] == '[') {
      final mark = rest[1];
      final closing = rest[2];
      if (closing == ']') {
        if (mark == ' ') checked = false;
        if (mark == 'x' || mark == 'X') checked = true;
      }
      if (checked != null) {
        var after = 3;
        while (
            after < rest.length && (rest[after] == ' ' || rest[after] == '\t')) {
          after += 1;
        }
        rest = rest.substring(after);
      }
    }

    // 들여쓰기 두 칸이 한 단. 네 칸씩 쓰는 사람에게는 두 단으로 보이지만,
    // 어느 쪽이든 "안쪽"이라는 관계는 그대로 읽힌다.
    return _RawListItem(
      indent: spaces ~/ 2,
      ordinal: ordinal,
      checked: checked,
      text: rest,
    );
  }

  static bool _isDigit(String character) {
    final code = character.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }
}

class _RawListItem {
  final int indent;
  final int? ordinal;
  final bool? checked;
  final String text;

  const _RawListItem({
    required this.indent,
    required this.ordinal,
    required this.checked,
    required this.text,
  });
}

/// 펜스 코드블록의 여는 줄.
class _CodeFence {
  final String character;
  final int length;
  final String? language;

  const _CodeFence({
    required this.character,
    required this.length,
    required this.language,
  });

  static _CodeFence? parse(String line) {
    var cursor = 0;
    var indent = 0;
    while (cursor < line.length && line[cursor] == ' ') {
      cursor += 1;
      indent += 1;
    }
    if (indent > 3 || cursor >= line.length) return null;
    final first = line[cursor];
    if (first != '`' && first != '~') return null;

    var length = 0;
    while (cursor < line.length && line[cursor] == first) {
      cursor += 1;
      length += 1;
    }
    if (length < 3) return null;

    final info = line.substring(cursor).trim();
    // 백틱 펜스의 정보 문자열에는 백틱이 들어갈 수 없다 — 인라인 코드와 헷갈린다.
    if (first == '`' && info.contains('`')) return null;

    return _CodeFence(
      character: first,
      length: length,
      language: info.isEmpty ? null : info,
    );
  }

  /// 이 줄이 이 펜스를 닫는가.
  bool closes(String line) {
    final trimmed = line.trim();
    if (trimmed.length < length) return false;
    return trimmed.split('').every((c) => c == character);
  }
}
