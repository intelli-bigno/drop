/// 본문 체크박스를 **눌러서** 끄고 켜는 규칙 (BRU-207).
///
/// 뷰어가 체크박스를 그리기만 하던 시절에는 필요 없던 계약이다. 이제 화면이
/// 체크박스를 누르면 본문 한 줄이 바뀌므로, "어느 줄을 바꿀 것인가"를 화면이
/// 세지 않고 파서가 알려 준다 — 화면이 따로 세면 인용 안의 체크박스나
/// 코드 펜스 안의 `- [ ]` 에서 반드시 어긋난다.
library;

import 'package:drop_core/drop_core.dart';
import 'package:test/test.dart';

/// 문서 안의 모든 목록 항목을 그리는 순서대로 편다.
List<MarkdownListItem> itemsOf(MarkdownDocument document) {
  final items = <MarkdownListItem>[];
  void walk(List<MarkdownBlock> blocks) {
    for (final block in blocks) {
      switch (block) {
        case MarkdownList(items: final listItems):
          items.addAll(listItems);
        case MarkdownQuote(blocks: final inner):
          walk(inner);
        default:
          break;
      }
    }
  }

  walk(document.blocks);
  return items;
}

void main() {
  const parser = MarkdownParser();

  group('파서가 목록 항목의 원본 줄 번호를 알려 준다', () {
    test('최상위 목록', () {
      const source = '제목\n\n- [ ] 하나\n- [x] 둘\n- 셋';
      final items = itemsOf(parser.parse(source));

      expect(items.map((item) => item.sourceLine), [2, 3, 4]);
    });

    test('인용 안의 체크박스도 원본 줄을 든다', () {
      const source = '- [ ] 밖\n\n> - [x] 인용 안';
      final items = itemsOf(parser.parse(source));

      expect(items.map((item) => item.sourceLine), [0, 2]);
    });

    test('코드 펜스 안의 체크박스는 항목이 아니다', () {
      const source = '- [ ] 진짜\n\n```\n- [ ] 코드 안\n```';
      final items = itemsOf(parser.parse(source));

      expect(items.length, 1);
      expect(items.single.sourceLine, 0);
    });
  });

  group('MarkdownChecklist.toggleLine', () {
    test('끈 것을 켜고, 켠 것을 끈다', () {
      const source = '- [ ] 하나\n- [x] 둘';

      expect(MarkdownChecklist.toggleLine(source, 0), '- [x] 하나\n- [x] 둘');
      expect(MarkdownChecklist.toggleLine(source, 1), '- [ ] 하나\n- [ ] 둘');
    });

    test('들여쓰기·표식·본문을 그대로 둔다', () {
      const source = '  * [X] 들여쓴 항목  ';

      expect(MarkdownChecklist.toggleLine(source, 0), '  * [ ] 들여쓴 항목  ');
    });

    test('순서 목록의 체크박스도 뒤집는다', () {
      expect(MarkdownChecklist.toggleLine('1. [ ] 첫째', 0), '1. [x] 첫째');
    });

    test('체크박스가 아닌 줄은 그대로 돌려준다', () {
      const source = '그냥 문단\n- 체크박스 아님';

      expect(MarkdownChecklist.toggleLine(source, 0), source);
      expect(MarkdownChecklist.toggleLine(source, 1), source);
    });

    test('범위를 벗어난 줄은 그대로 돌려준다', () {
      const source = '- [ ] 하나';

      expect(MarkdownChecklist.toggleLine(source, -1), source);
      expect(MarkdownChecklist.toggleLine(source, 9), source);
    });

    test('줄 끝 문자를 보존한다 — 마지막 줄이 개행으로 끝나면 그대로 둔다', () {
      expect(MarkdownChecklist.toggleLine('- [ ] 하나\n', 0), '- [x] 하나\n');
    });
  });

  group('MarkdownChecklist.progress', () {
    test('전체와 완료 수를 센다', () {
      const source = '- [ ] 하나\n- [x] 둘\n- [X] 셋\n- 넷';
      final progress = MarkdownChecklist.progress(source);

      expect(progress.total, 3);
      expect(progress.completed, 2);
      expect(progress.isComplete, isFalse);
    });

    test('체크박스가 없으면 전체가 0이다', () {
      expect(MarkdownChecklist.progress('그냥 글').total, 0);
    });

    test('다 끝냈으면 완료다', () {
      expect(MarkdownChecklist.progress('- [x] 하나').isComplete, isTrue);
    });
  });
}
