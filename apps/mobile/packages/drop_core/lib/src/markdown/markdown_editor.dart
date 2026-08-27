/// 작성 시트 툴바 뒤의 편집 계산. DropCore `MarkdownEditor.swift` 대응.
///
/// "무엇을 어디에 끼워 넣고 커서를 어디 두느냐"는 순수 함수로 떨어지고,
/// 그래야 에뮬레이터 없이 `dart test`로 잡힌다 (BRU-37).
///
/// 자리는 전부 UTF-16 코드유닛 기준이다 — Dart `String`의 인덱스 단위이자
/// Flutter `TextEditingValue.selection`이 쓰는 단위다. 글자 수로 세면
/// 한글·이모지가 섞이는 순간 커서가 글자 가운데로 떨어진다.
library;

/// 작성 시트 툴바가 누를 수 있는 편집 동작.
enum MarkdownEditingCommand {
  bold,
  italic,

  /// 한 줄이면 인라인 코드, 여러 줄이면 펜스 코드블록.
  code,
  link,

  /// 누를 때마다 한 단계씩 깊어지고 여섯 단계 다음에 풀린다.
  heading,
  bulletList,
  checkbox,
  quote,
}

/// 선택 범위. Swift `NSRange` 대응 (UTF-16 코드유닛).
class EditorRange {
  final int location;
  final int length;

  const EditorRange(this.location, this.length);

  int get end => location + length;

  @override
  bool operator ==(Object other) =>
      other is EditorRange &&
      other.location == location &&
      other.length == length;

  @override
  int get hashCode => Object.hash(location, length);

  @override
  String toString() => 'EditorRange($location, $length)';
}

/// 명령을 적용한 결과. 새 글자와, 그 글자 위에서 커서가 있어야 할 자리.
class MarkdownEditingResult {
  final String text;
  final EditorRange selection;

  const MarkdownEditingResult({required this.text, required this.selection});

  @override
  bool operator ==(Object other) =>
      other is MarkdownEditingResult &&
      other.text == text &&
      other.selection == selection;

  @override
  int get hashCode => Object.hash(text, selection);

  @override
  String toString() => 'MarkdownEditingResult($text, $selection)';
}

/// 툴바 뒤의 계산. **화면이 아니라 여기가 정본이다.**
class MarkdownEditor {
  MarkdownEditor._();

  static MarkdownEditingResult apply(
    MarkdownEditingCommand command,
    String text,
    EditorRange selection,
  ) {
    final range = _clamp(selection, text.length);

    return switch (command) {
      MarkdownEditingCommand.bold => _wrap('**', text, range),
      MarkdownEditingCommand.italic => _wrap('*', text, range),
      MarkdownEditingCommand.code => _applyCode(text, range),
      MarkdownEditingCommand.link => _applyLink(text, range),
      MarkdownEditingCommand.heading ||
      MarkdownEditingCommand.bulletList ||
      MarkdownEditingCommand.checkbox ||
      MarkdownEditingCommand.quote =>
        _applyLinePrefix(command, text, range),
    };
  }

  static EditorRange _clamp(EditorRange range, int length) {
    final location = range.location.clamp(0, length);
    final clampedLength = range.length.clamp(0, length - location);
    return EditorRange(location, clampedLength);
  }

  // 감싸기

  /// 이미 감싸여 있으면 푼다 — 같은 버튼이 켜고 끄기 둘 다를 한다.
  static MarkdownEditingResult _wrap(
    String marker,
    String source,
    EditorRange range,
  ) {
    final width = marker.length;

    if (range.length == 0) {
      final text =
          source.replaceRange(range.location, range.end, marker + marker);
      return MarkdownEditingResult(
        text: text,
        selection: EditorRange(range.location + width, 0),
      );
    }

    final selected = source.substring(range.location, range.end);

    // 기호까지 함께 고른 경우.
    if (selected.startsWith(marker) &&
        selected.endsWith(marker) &&
        selected.length >= width * 2) {
      final inner = selected.substring(width, selected.length - width);
      return MarkdownEditingResult(
        text: source.replaceRange(range.location, range.end, inner),
        selection: EditorRange(range.location, inner.length),
      );
    }

    // 기호 안쪽만 고른 경우.
    final beforeStart = range.location - width;
    final afterEnd = range.end + width;
    if (beforeStart >= 0 &&
        afterEnd <= source.length &&
        source.substring(beforeStart, range.location) == marker &&
        source.substring(range.end, afterEnd) == marker) {
      final stripped = source.replaceRange(range.end, afterEnd, '')
          .replaceRange(beforeStart, range.location, '');
      return MarkdownEditingResult(
        text: stripped,
        selection: EditorRange(range.location - width, range.length),
      );
    }

    return MarkdownEditingResult(
      text: source.replaceRange(
          range.location, range.end, marker + selected + marker),
      selection: EditorRange(range.location + width, range.length),
    );
  }

  // 코드

  /// 여러 줄에 백틱 하나를 두르면 렌더가 깨진다 — 그때는 펜스가 답이다.
  static MarkdownEditingResult _applyCode(String source, EditorRange range) {
    final selected = source.substring(range.location, range.end);
    if (!selected.contains('\n')) return _wrap('`', source, range);

    final fenced = '```\n$selected\n```';
    return MarkdownEditingResult(
      text: source.replaceRange(range.location, range.end, fenced),
      selection: EditorRange(range.location + 4, selected.length),
    );
  }

  // 링크

  /// 채울 자리를 골라 둔 채로 넘긴다 — 모바일에서 커서를 다시 찍는 것이 가장 번거롭다.
  static MarkdownEditingResult _applyLink(String source, EditorRange range) {
    const placeholder = 'url';
    const width = placeholder.length;

    if (range.length == 0) {
      const label = '텍스트';
      const inserted = '[$label]($placeholder)';
      return MarkdownEditingResult(
        text: source.replaceRange(range.location, range.end, inserted),
        selection: EditorRange(range.location + 1, label.length),
      );
    }

    final selected = source.substring(range.location, range.end);
    final inserted = '[$selected]($placeholder)';
    return MarkdownEditingResult(
      text: source.replaceRange(range.location, range.end, inserted),
      // `[선택](` 뒤 = 1 + 선택 + 2
      selection: EditorRange(range.location + range.length + 3, width),
    );
  }

  // 줄 앞머리

  static MarkdownEditingResult _applyLinePrefix(
    MarkdownEditingCommand command,
    String source,
    EditorRange range,
  ) {
    final lines = _lineRanges(source, range);
    final bodies = lines.map((line) => _body(source, line)).toList();

    // 일부만 붙어 있을 때 "떼기"로 판정하면 나머지 줄이 영영 목록이 되지 못한다.
    final removes = bodies.isNotEmpty &&
        bodies.every((body) => _hasPrefix(command, _split(body).$2));
    // 제목은 켜고 끄기가 아니라 단계 오르기다 — 첫 줄을 보고 목표 단계를 정한다.
    final headingTarget = bodies.isEmpty
        ? 1
        : (_headingLevel(_split(bodies.first).$2) + 1) % 7;

    var updated = source;
    var deltaBeforeSelection = 0;
    var totalDelta = 0;

    for (var i = lines.length - 1; i >= 0; i -= 1) {
      final line = lines[i];
      final body = bodies[i];
      final (indent, rest) = _split(body);
      final newRest = _transform(command, rest, removes, headingTarget);
      final newBody = indent + newRest;
      final delta = newBody.length - body.length;
      if (delta == 0) continue;
      updated = updated.replaceRange(
          line.location, line.location + body.length, newBody);
      totalDelta += delta;
      if (line.location <= range.location) deltaBeforeSelection += delta;
    }

    final location = range.location + deltaBeforeSelection;
    final length = range.length + totalDelta - deltaBeforeSelection;
    return MarkdownEditingResult(
      text: updated,
      selection: EditorRange(
        location < 0 ? 0 : location,
        length < 0 ? 0 : length,
      ),
    );
  }

  /// 고른 범위가 스치는 줄 전부. 길이 0짜리 선택도 그 줄 하나는 잡아야 한다.
  static List<EditorRange> _lineRanges(String source, EditorRange range) {
    if (source.isEmpty) return const [EditorRange(0, 0)];

    // 범위가 실제로 덮는 마지막 문자.
    var anchor = range.length > 0 ? range.end - 1 : range.location;
    if (anchor >= source.length) anchor = source.length - 1;

    var start = range.location.clamp(0, source.length);
    while (start > 0 && source.codeUnitAt(start - 1) != 0x0A) {
      start -= 1;
    }
    if (anchor < start) anchor = start;

    var end = anchor;
    while (end < source.length && source.codeUnitAt(end) != 0x0A) {
      end += 1;
    }
    if (end < source.length) end += 1; // 줄바꿈 포함

    final ranges = <EditorRange>[];
    var cursor = start;
    while (cursor < end) {
      var lineEnd = cursor;
      while (lineEnd < end && source.codeUnitAt(lineEnd) != 0x0A) {
        lineEnd += 1;
      }
      if (lineEnd < end) lineEnd += 1;
      ranges.add(EditorRange(cursor, lineEnd - cursor));
      cursor = lineEnd;
    }
    return ranges.isEmpty ? [EditorRange(range.location, 0)] : ranges;
  }

  /// 줄 범위에서 줄바꿈 문자를 뺀 알맹이.
  static String _body(String source, EditorRange line) {
    var text =
        line.length > 0 ? source.substring(line.location, line.end) : '';
    while (text.endsWith('\n') || text.endsWith('\r')) {
      text = text.substring(0, text.length - 1);
    }
    return text;
  }

  static (String, String) _split(String body) {
    var cursor = 0;
    while (cursor < body.length &&
        (body[cursor] == ' ' || body[cursor] == '\t')) {
      cursor += 1;
    }
    return (body.substring(0, cursor), body.substring(cursor));
  }

  static String _transform(
    MarkdownEditingCommand command,
    String rest,
    bool removes,
    int headingTarget,
  ) {
    final marker = _listMarker(rest);

    switch (command) {
      case MarkdownEditingCommand.heading:
        final stripped = _strippingHeading(rest);
        return headingTarget == 0 ? stripped : '${'#' * headingTarget} $stripped';

      case MarkdownEditingCommand.bulletList:
        // 불릿을 떼면 체크칸까지 함께 떨어진다 — 표식만 남으면 아무 뜻도 없다.
        if (removes) return rest.substring(marker.total);
        return '- $rest';

      case MarkdownEditingCommand.checkbox:
        if (removes) return rest.substring(marker.total);
        if (marker.bullet == 0) return '- [ ] $rest';
        return '${rest.substring(0, marker.bullet)}[ ] ${rest.substring(marker.bullet)}';

      case MarkdownEditingCommand.quote:
        if (removes) return rest.substring(_quotePrefixLength(rest));
        return '> $rest';

      case MarkdownEditingCommand.bold ||
            MarkdownEditingCommand.italic ||
            MarkdownEditingCommand.code ||
            MarkdownEditingCommand.link:
        return rest;
    }
  }

  static bool _hasPrefix(MarkdownEditingCommand command, String rest) =>
      switch (command) {
        MarkdownEditingCommand.bulletList => _listMarker(rest).bullet > 0,
        MarkdownEditingCommand.checkbox => _listMarker(rest).checkbox > 0,
        MarkdownEditingCommand.quote => _quotePrefixLength(rest) > 0,
        _ => false,
      };

  // 앞머리 알아보기

  static _ListMarker _listMarker(String rest) {
    var bullet = 0;
    var cursorStart = 0;

    if (rest.isNotEmpty && '-*+'.contains(rest[0])) {
      var spaces = 0;
      var probe = 1;
      while (probe < rest.length &&
          (rest[probe] == ' ' || rest[probe] == '\t')) {
        spaces += 1;
        probe += 1;
      }
      if (spaces > 0) {
        bullet = 1 + spaces;
        cursorStart = probe;
      }
    }

    var checkbox = 0;
    if (bullet > 0 && rest.length - cursorStart >= 3 && rest[cursorStart] == '[') {
      final mark = rest[cursorStart + 1];
      final closing = rest[cursorStart + 2];
      if (closing == ']' && (mark == ' ' || mark == 'x' || mark == 'X')) {
        var spaces = 0;
        var probe = cursorStart + 3;
        while (probe < rest.length &&
            (rest[probe] == ' ' || rest[probe] == '\t')) {
          spaces += 1;
          probe += 1;
        }
        checkbox = 3 + spaces;
      }
    }

    return _ListMarker(bullet: bullet, checkbox: checkbox);
  }

  static int _quotePrefixLength(String rest) {
    if (rest.isEmpty || rest[0] != '>') return 0;
    var spaces = 0;
    var cursor = 1;
    while (cursor < rest.length &&
        (rest[cursor] == ' ' || rest[cursor] == '\t')) {
      spaces += 1;
      cursor += 1;
    }
    return 1 + spaces;
  }

  static int _headingLevel(String rest) {
    var hashes = 0;
    while (hashes < rest.length && rest[hashes] == '#') {
      hashes += 1;
    }
    if (hashes < 1 || hashes > 6) return 0;
    if (hashes < rest.length && rest[hashes] != ' ') return 0;
    return hashes;
  }

  static String _strippingHeading(String rest) {
    final level = _headingLevel(rest);
    if (level == 0) return rest;
    var cursor = level;
    while (cursor < rest.length &&
        (rest[cursor] == ' ' || rest[cursor] == '\t')) {
      cursor += 1;
    }
    return rest.substring(cursor);
  }
}

class _ListMarker {
  /// `- ` 길이. 0이면 불릿이 없다.
  final int bullet;

  /// `[ ] ` 길이. 0이면 체크칸이 없다.
  final int checkbox;

  int get total => bullet + checkbox;

  const _ListMarker({required this.bullet, required this.checkbox});
}
