import 'markdown_document.dart';

/// 한 줄 안에서 글자에 걸리는 문법 — 굵게·기울임·인라인 코드·링크.
/// DropCore `MarkdownInlineParser.swift` 대응.
///
/// 블록 파서와 갈라 둔 이유는 규칙의 성격이 다르기 때문이다. 블록은 줄을 보고
/// 판단하면 끝나지만, 인라인은 "닫는 짝이 있느냐"를 앞뒤로 살펴야 하고
/// 짝이 없으면 **글자 그대로 남겨야 한다** — 쓰는 도중의 노트가 절반쯤 사라지면 안 된다.
class MarkdownInlineParser {
  const MarkdownInlineParser();

  /// 역슬래시로 글자 취급을 강제할 수 있는 기호.
  static const _escapable = {
    '\\', '`', '*', '_', '[', ']', '(', ')', '#', '+', '-', '.', '!', '>',
    '~', '|', '{', '}', //
  };

  static final _letterOrNumber = RegExp(r'[\p{L}\p{N}]', unicode: true);

  List<MarkdownInline> parse(String text) => _parse(text, 0, text.length);

  List<MarkdownInline> _parse(String text, int start, int end) {
    final nodes = <MarkdownInline>[];
    final pending = StringBuffer();
    var index = start;

    void flush() {
      if (pending.isEmpty) return;
      nodes.add(MarkdownText(pending.toString()));
      pending.clear();
    }

    while (index < end) {
      final character = text[index];

      switch (character) {
        case '\\':
          final next = index + 1;
          // 기호가 아닌 글자 앞의 역슬래시는 글자다 — 윈도우 경로가 사라지면 안 된다.
          if (next < end && _escapable.contains(text[next])) {
            pending.write(text[next]);
            index = next + 1;
          } else {
            pending.write(character);
            index += 1;
          }

        case '`':
          final close = _indexOf(text, '`', index + 1, end);
          if (close >= 0) {
            flush();
            nodes.add(MarkdownCode(text.substring(index + 1, close)));
            index = close + 1;
          } else {
            pending.write(character);
            index += 1;
          }

        case '*' || '_':
          final result = _emphasis(text, start, end, index);
          if (result != null) {
            flush();
            nodes.add(result.$1);
            index = result.$2;
          } else {
            pending.write(character);
            index += 1;
          }

        case '[':
          final result = _link(text, end, index);
          if (result != null) {
            flush();
            nodes.add(result.$1);
            index = result.$2;
          } else {
            pending.write(character);
            index += 1;
          }

        default:
          pending.write(character);
          index += 1;
      }
    }

    flush();
    return nodes;
  }

  static int _indexOf(String text, String character, int from, int end) {
    for (var i = from; i < end; i += 1) {
      if (text[i] == character) return i;
    }
    return -1;
  }

  static bool _isLetterOrNumber(String character) =>
      _letterOrNumber.hasMatch(character);

  // 강조

  (MarkdownInline, int)? _emphasis(String text, int start, int end, int at) {
    final marker = text[at];
    final openingRun = _run(text, marker, at, end);
    final width = openingRun >= 2 ? 2 : 1;

    // `_`는 단어 안에서 강조가 되지 않는다 — `snake_case_name`이 기울임이 되면
    // 코드 이름을 적은 노트가 통째로 뭉개진다.
    if (marker == '_' && at > start) {
      final previous = text[at - 1];
      if (_isLetterOrNumber(previous)) return null;
    }

    final contentStart = at + width;
    if (contentStart >= end) return null;
    final close = _closingRun(text, marker, width, contentStart, end);
    if (close == null) return null;

    if (marker == '_') {
      final after = close + width;
      if (after < end && _isLetterOrNumber(text[after])) return null;
    }

    final content = _parse(text, contentStart, close);
    if (content.isEmpty) return null;
    final node = width == 2
        ? MarkdownStrong(content) as MarkdownInline
        : MarkdownEmphasis(content);
    return (node, close + width);
  }

  /// 닫는 표식의 시작 위치.
  ///
  /// 표식이 세 개 이상 몰려 있으면(`***기울고***`) **뒤쪽을 닫는 짝으로 잡는다** —
  /// 앞쪽을 잡으면 안쪽 강조가 통째로 글자로 떨어진다.
  int? _closingRun(String text, String marker, int width, int from, int end) {
    var index = from;
    while (index < end) {
      if (text[index] != marker) {
        index += 1;
        continue;
      }
      final length = _run(text, marker, index, end);
      if (length >= width) {
        return index + length - width;
      }
      index += length;
    }
    return null;
  }

  int _run(String text, String marker, int from, int end) {
    var length = 0;
    var index = from;
    while (index < end && text[index] == marker) {
      length += 1;
      index += 1;
    }
    return length;
  }

  // 링크

  (MarkdownInline, int)? _link(String text, int end, int at) {
    var depth = 0;
    var index = at;
    int? labelEnd;

    while (index < end) {
      switch (text[index]) {
        case '[':
          depth += 1;
        case ']':
          depth -= 1;
          if (depth == 0) labelEnd = index;
      }
      if (labelEnd != null) break;
      index += 1;
    }

    if (labelEnd == null) return null;
    final parenStart = labelEnd + 1;
    if (parenStart >= end || text[parenStart] != '(') return null;
    final parenEnd = _indexOf(text, ')', parenStart, end);
    if (parenEnd < 0) return null;

    final inside = text.substring(parenStart + 1, parenEnd);
    // `[글](주소 "제목")`의 제목은 화면에 쓸 데가 없다.
    final destination = inside
        .split(' ')
        .firstWhere((part) => part.isNotEmpty, orElse: () => '');
    if (destination.isEmpty) return null;

    final content = _parse(text, at + 1, labelEnd);
    if (content.isEmpty) return null;
    return (
      MarkdownLink(content: content, destination: destination),
      parenEnd + 1,
    );
  }
}
