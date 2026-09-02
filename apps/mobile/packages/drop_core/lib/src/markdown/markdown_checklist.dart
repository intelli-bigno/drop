/// 본문 안 체크박스를 눌러 끄고 켜는 규칙 (BRU-207).
///
/// **왜 도메인에 있나**: 화면이 `- [ ]`를 `- [x]`로 바꾸는 문자열 조작을 직접 하면,
/// 들여쓰기·표식(`-`/`*`/`1.`)·대문자 `X`·줄 끝 공백 같은 경우를 화면마다 다르게
/// 다루게 된다. 규칙은 하나여야 하고, 시뮬레이터 없이 검증돼야 한다.
///
/// **뷰어의 읽기 전용 계약과의 관계**: 뷰어가 본문을 못 건드리게 막은 것(BRU-77)은
/// *열람만 했는데 본문이 조용히 덮어써지던 사고*(BRU-66) 때문이다. 체크박스를
/// 손가락으로 누르는 것은 조용하지도 않고 모호하지도 않다 — 그래서 이 한 줄짜리
/// 변경만 예외로 연다. 본문 전체를 고치는 길은 여전히 편집기뿐이다.
library;

/// 체크박스 진행 상황.
class ChecklistProgress {
  final int total;
  final int completed;

  const ChecklistProgress({required this.total, required this.completed});

  bool get isEmpty => total == 0;

  bool get isComplete => total > 0 && completed == total;

  /// 0.0~1.0. 체크박스가 없으면 0.
  double get fraction => total == 0 ? 0 : completed / total;
}

abstract final class MarkdownChecklist {
  /// [lineIndex]번째 줄이 체크박스면 뒤집은 본문을, 아니면 [source] 그대로 돌려준다.
  ///
  /// 줄 번호는 화면이 세지 않는다 — 파서가 `MarkdownListItem.sourceLine`으로
  /// 알려 준 값을 그대로 넘긴다.
  static String toggleLine(String source, int lineIndex) {
    final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');
    if (lineIndex < 0 || lineIndex >= lines.length) return source;

    final flipped = _flip(lines[lineIndex]);
    if (flipped == null) return source;

    lines[lineIndex] = flipped;
    return lines.join('\n');
  }

  /// 본문 전체의 체크박스 수와 그중 끝낸 수.
  static ChecklistProgress progress(String source) {
    final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    var total = 0;
    var completed = 0;
    var inFence = false;
    for (final line in normalized.split('\n')) {
      // 코드 펜스 안의 `- [ ]`는 글자일 뿐이다 — 파서와 같은 판단을 해야
      // 화면의 개수와 여기 개수가 어긋나지 않는다.
      if (_isFence(line)) {
        inFence = !inFence;
        continue;
      }
      if (inFence) continue;

      final checked = _checkedOf(line);
      if (checked == null) continue;
      total += 1;
      if (checked) completed += 1;
    }
    return ChecklistProgress(total: total, completed: completed);
  }

  static bool _isFence(String line) {
    final trimmed = line.trimLeft();
    return trimmed.startsWith('```') || trimmed.startsWith('~~~');
  }

  /// 체크박스 줄이면 그 상태를, 아니면 null.
  static bool? _checkedOf(String line) => _markAt(line)?.$2;

  /// 뒤집은 줄. 체크박스가 아니면 null.
  static String? _flip(String line) {
    final mark = _markAt(line);
    if (mark == null) return null;
    final (index, checked) = mark;
    return line.replaceRange(index, index + 1, checked ? ' ' : 'x');
  }

  /// 체크 표시 문자의 위치와 상태. `- [x] 할일`이면 `x`의 자리와 true.
  ///
  /// 목록 표식 판정은 `MarkdownParser._listItem`과 같은 규칙이다:
  /// 앞 공백 → 표식(`-`/`*`/`+` 또는 숫자+`.`/`)`) → 공백 → `[ ]`/`[x]`.
  static (int, bool)? _markAt(String line) {
    var cursor = 0;
    while (cursor < line.length &&
        (line[cursor] == ' ' || line[cursor] == '\t')) {
      cursor += 1;
    }
    if (cursor >= line.length) return null;

    final marker = line[cursor];
    if ('-*+'.contains(marker)) {
      cursor += 1;
    } else if (_isDigit(marker)) {
      while (cursor < line.length && _isDigit(line[cursor])) {
        cursor += 1;
      }
      if (cursor >= line.length) return null;
      final delimiter = line[cursor];
      if (delimiter != '.' && delimiter != ')') return null;
      cursor += 1;
    } else {
      return null;
    }

    // 표식 뒤에는 공백이 와야 한다 — 아니면 `-[x]`도 체크박스가 된다.
    if (cursor >= line.length) return null;
    if (line[cursor] != ' ' && line[cursor] != '\t') return null;
    while (cursor < line.length &&
        (line[cursor] == ' ' || line[cursor] == '\t')) {
      cursor += 1;
    }

    if (cursor + 2 >= line.length) return null;
    if (line[cursor] != '[' || line[cursor + 2] != ']') return null;
    final mark = line[cursor + 1];
    if (mark == ' ') return (cursor + 1, false);
    if (mark == 'x' || mark == 'X') return (cursor + 1, true);
    return null;
  }

  static bool _isDigit(String character) {
    final code = character.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }
}
