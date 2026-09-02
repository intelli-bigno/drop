import '../collection_equality.dart';

/// 파싱한 노트 본문. DropCore `MarkdownDocument.swift` 대응.
///
/// **`source`는 넣은 문자열 그대로다.** 이 타입은 렌더링을 위한 읽기 전용 표현이고,
/// 저장 경로와는 아무 관계가 없다 — 열람만 했는데 본문이 달라지는 일(BRU-66)을
/// 구조적으로 막으려면 "원문은 늘 여기 그대로 있다"가 타입에 드러나야 한다.
class MarkdownDocument {
  /// 파서에 들어온 문자열. 한 글자도 손대지 않는다.
  final String source;
  final List<MarkdownBlock> blocks;

  const MarkdownDocument({required this.source, required this.blocks});

  bool get isEmpty => blocks.isEmpty;

  /// 문법 기호를 걷어낸 글자.
  ///
  /// 목록 한 줄 행(BRU-49)처럼 서식을 그릴 수 없는 자리에 쓴다. 원문을 그대로
  /// 태우면 `## 제목`이 `##`째로 보이는데, 한 줄만 보이는 자리에서는 기호가
  /// 읽을 수 있는 정보의 절반을 먹는다.
  String get plainText => _plainTextOf(blocks).join('\n');

  /// 줄바꿈과 잇단 공백까지 접어 한 줄로 만든 글자.
  String get singleLineSummary => plainText
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .join(' ');

  static List<String> _plainTextOf(List<MarkdownBlock> blocks) =>
      blocks.expand<String>((block) {
        switch (block) {
          case MarkdownHeading(:final content):
            return [content.plainText];
          case MarkdownParagraph(:final content):
            return [content.plainText];
          case MarkdownList(:final items):
            return items.map((item) =>
                ' ' * (item.indent * 2) + _marker(item) + item.content.plainText);
          case MarkdownCodeBlock(:final code):
            return [code];
          case MarkdownQuote(:final blocks):
            return _plainTextOf(blocks);
          case MarkdownThematicBreak():
            // 줄 하나를 통째로 먹으면서 글자는 하나도 없다 — 요약에서는 없는 편이 낫다.
            return const [];
        }
      }).toList();

  static String _marker(MarkdownListItem item) {
    final checked = item.checked;
    if (checked != null) return checked ? '☑ ' : '☐ ';
    final ordinal = item.ordinal;
    if (ordinal != null) return '$ordinal. ';
    return '• ';
  }
}

/// 블록 요소. 문단·제목·목록처럼 줄 단위로 갈리는 것들.
sealed class MarkdownBlock {
  const MarkdownBlock();
}

class MarkdownHeading extends MarkdownBlock {
  final int level;
  final List<MarkdownInline> content;

  const MarkdownHeading({required this.level, required this.content});

  @override
  bool operator ==(Object other) =>
      other is MarkdownHeading &&
      other.level == level &&
      listEquals(other.content, content);

  @override
  int get hashCode => Object.hash(level, listHash(content));

  @override
  String toString() => 'Heading($level, $content)';
}

class MarkdownParagraph extends MarkdownBlock {
  final List<MarkdownInline> content;

  const MarkdownParagraph(this.content);

  @override
  bool operator ==(Object other) =>
      other is MarkdownParagraph && listEquals(other.content, content);

  @override
  int get hashCode => listHash(content);

  @override
  String toString() => 'Paragraph($content)';
}

/// 불릿·번호·체크박스가 한 덩어리로 들어온다. 항목마다 표식이 달려 있어
/// 섞인 목록(`- 하나` 다음 `1. 둘`)도 한 블록으로 다룬다.
class MarkdownList extends MarkdownBlock {
  final List<MarkdownListItem> items;

  const MarkdownList(this.items);

  @override
  bool operator ==(Object other) =>
      other is MarkdownList && listEquals(other.items, items);

  @override
  int get hashCode => listHash(items);

  @override
  String toString() => 'List($items)';
}

class MarkdownCodeBlock extends MarkdownBlock {
  final String? language;
  final String code;

  const MarkdownCodeBlock({required this.language, required this.code});

  @override
  bool operator ==(Object other) =>
      other is MarkdownCodeBlock &&
      other.language == language &&
      other.code == code;

  @override
  int get hashCode => Object.hash(language, code);

  @override
  String toString() => 'CodeBlock($language, $code)';
}

class MarkdownQuote extends MarkdownBlock {
  final List<MarkdownBlock> blocks;

  const MarkdownQuote(this.blocks);

  @override
  bool operator ==(Object other) =>
      other is MarkdownQuote && listEquals(other.blocks, blocks);

  @override
  int get hashCode => listHash(blocks);

  @override
  String toString() => 'Quote($blocks)';
}

class MarkdownThematicBreak extends MarkdownBlock {
  const MarkdownThematicBreak();

  @override
  bool operator ==(Object other) => other is MarkdownThematicBreak;

  @override
  int get hashCode => (MarkdownThematicBreak).hashCode;

  @override
  String toString() => 'ThematicBreak';
}

/// 목록 한 항목.
///
/// 중첩을 트리가 아니라 `indent` 값으로 평평하게 들고 있다 — 노트에 들어오는
/// 목록은 깊어야 두세 단이고, 트리로 만들면 파서와 렌더가 함께 복잡해진다.
class MarkdownListItem {
  /// 0이 최상위. 들여쓴 공백 두 칸이 한 단이다.
  final int indent;

  /// `null`이면 불릿, 값이 있으면 순서 목록의 그 번호.
  final int? ordinal;

  /// `null`이면 체크박스가 아닌 보통 항목.
  final bool? checked;
  final List<MarkdownInline> content;

  /// 이 항목이 온 **원본 줄 번호**(0부터). 체크박스를 눌러 끄고 켤 때 화면이
  /// "몇 번째 체크박스인가"를 직접 세지 않게 하려고 파서가 들려 보낸다 —
  /// 화면이 세면 인용 안의 체크박스나 코드 펜스 안의 `- [ ]`에서 어긋난다.
  final int sourceLine;

  const MarkdownListItem({
    required this.indent,
    required this.ordinal,
    required this.checked,
    required this.content,
    this.sourceLine = -1,
  });

  @override
  bool operator ==(Object other) =>
      other is MarkdownListItem &&
      other.indent == indent &&
      other.ordinal == ordinal &&
      other.checked == checked &&
      listEquals(other.content, content);

  @override
  int get hashCode => Object.hash(indent, ordinal, checked, listHash(content));

  @override
  String toString() => 'Item(indent: $indent, ordinal: $ordinal, checked: $checked, $content)';
}

/// 인라인 요소. 한 줄 안에서 글자에 걸리는 것들.
sealed class MarkdownInline {
  const MarkdownInline();

  /// 문법을 걷어낸 글자.
  String get plainText => switch (this) {
        MarkdownText(:final value) => value,
        MarkdownStrong(:final content) => content.plainText,
        MarkdownEmphasis(:final content) => content.plainText,
        MarkdownCode(:final value) => value,
        MarkdownLink(:final content) => content.plainText,
      };
}

class MarkdownText extends MarkdownInline {
  final String value;

  const MarkdownText(this.value);

  @override
  bool operator ==(Object other) => other is MarkdownText && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Text($value)';
}

class MarkdownStrong extends MarkdownInline {
  final List<MarkdownInline> content;

  const MarkdownStrong(this.content);

  @override
  bool operator ==(Object other) =>
      other is MarkdownStrong && listEquals(other.content, content);

  @override
  int get hashCode => listHash(content);

  @override
  String toString() => 'Strong($content)';
}

class MarkdownEmphasis extends MarkdownInline {
  final List<MarkdownInline> content;

  const MarkdownEmphasis(this.content);

  @override
  bool operator ==(Object other) =>
      other is MarkdownEmphasis && listEquals(other.content, content);

  @override
  int get hashCode => listHash(content);

  @override
  String toString() => 'Emphasis($content)';
}

class MarkdownCode extends MarkdownInline {
  final String value;

  const MarkdownCode(this.value);

  @override
  bool operator ==(Object other) => other is MarkdownCode && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Code($value)';
}

class MarkdownLink extends MarkdownInline {
  final List<MarkdownInline> content;
  final String destination;

  const MarkdownLink({required this.content, required this.destination});

  @override
  bool operator ==(Object other) =>
      other is MarkdownLink &&
      listEquals(other.content, content) &&
      other.destination == destination;

  @override
  int get hashCode => Object.hash(listHash(content), destination);

  @override
  String toString() => 'Link($content → $destination)';
}

extension MarkdownInlineListPlainText on List<MarkdownInline> {
  String get plainText => map((inline) => inline.plainText).join();
}
