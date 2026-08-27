import 'package:drop_core/drop_core.dart';
import 'package:test/test.dart';

/// DropCore `MarkdownParserTests.swift` 포팅.
/// 블록 문법 파서. 화면도 에뮬레이터도 없이 검증한다 (BRU-37).
void main() {
  const parser = MarkdownParser();

  List<MarkdownBlock> blocks(String source) => parser.parse(source).blocks;

  group('마크다운 파서 — 블록', () {
    // 원문 보존 (BRU-66)

    /// **이 파서는 렌더링만 한다.** 원문을 손대는 순간 "열람했더니 내용이 바뀌었다"가
    /// 되고, 그것이 BRU-66에서 실제로 일어난 사고다. 어떤 입력이 들어와도
    /// `source`는 넣은 그대로여야 한다.
    test('파싱은 원문을 그대로 들고 있는다', () {
      final samples = [
        '',
        '  ',
        '# 제목\n\n본문',
        '- [ ] 할 일\n- [x] 한 일',
        '```swift\nlet x = 1\n```',
        '> 인용\n> 계속',
        '닫히지 않은 **굵게',
        '\r\n윈도우 줄바꿈\r\n',
        '이모지 🍊 와 한글',
      ];
      for (final sample in samples) {
        expect(parser.parse(sample).source, sample);
      }
    });

    // 문단

    test('빈 입력에는 블록이 없다', () {
      expect(blocks(''), isEmpty);
      expect(blocks('\n\n   \n'), isEmpty);
    });

    test('평범한 줄은 문단이 된다', () {
      expect(blocks('그냥 메모'), const [
        MarkdownParagraph([MarkdownText('그냥 메모')]),
      ]);
    });

    /// 노트 앱이라 사용자가 넣은 줄바꿈은 그대로 보여 준다 — CommonMark의
    /// "소프트 줄바꿈은 공백" 규칙을 따르면 손으로 나눈 줄이 뭉개진다.
    test('문단 안의 줄바꿈은 유지된다', () {
      expect(blocks('첫 줄\n둘째 줄'), const [
        MarkdownParagraph([MarkdownText('첫 줄\n둘째 줄')]),
      ]);
    });

    test('빈 줄은 문단을 가른다', () {
      expect(blocks('앞\n\n뒤'), const [
        MarkdownParagraph([MarkdownText('앞')]),
        MarkdownParagraph([MarkdownText('뒤')]),
      ]);
    });

    // 제목

    test('# 개수가 제목 단계다', () {
      for (var level = 1; level <= 6; level += 1) {
        final source = '${'#' * level} 제목';
        expect(blocks(source), [
          MarkdownHeading(level: level, content: const [MarkdownText('제목')]),
        ]);
      }
    });

    /// `#태그`를 제목으로 읽으면 DROP의 태그 표기가 전부 제목이 된다.
    test('# 뒤에 공백이 없으면 제목이 아니다', () {
      expect(blocks('#태그'), const [
        MarkdownParagraph([MarkdownText('#태그')]),
      ]);
    });

    test('#이 일곱 개면 제목이 아니다', () {
      expect(blocks('####### 너무 깊다'), const [
        MarkdownParagraph([MarkdownText('####### 너무 깊다')]),
      ]);
    });

    test('제목은 앞뒤 빈 줄 없이도 문단과 갈린다', () {
      expect(blocks('# 제목\n본문'), const [
        MarkdownHeading(level: 1, content: [MarkdownText('제목')]),
        MarkdownParagraph([MarkdownText('본문')]),
      ]);
    });

    // 목록

    test('-, *, + 는 모두 불릿 목록이다', () {
      for (final marker in ['-', '*', '+']) {
        expect(blocks('$marker 항목'), const [
          MarkdownList([
            MarkdownListItem(
              indent: 0,
              ordinal: null,
              checked: null,
              content: [MarkdownText('항목')],
            ),
          ]),
        ]);
      }
    });

    test('1. 과 1) 은 순서 목록이고 번호를 지킨다', () {
      expect(blocks('3. 셋\n4) 넷'), const [
        MarkdownList([
          MarkdownListItem(
            indent: 0,
            ordinal: 3,
            checked: null,
            content: [MarkdownText('셋')],
          ),
          MarkdownListItem(
            indent: 0,
            ordinal: 4,
            checked: null,
            content: [MarkdownText('넷')],
          ),
        ]),
      ]);
    });

    test('들여쓴 항목은 단계가 깊어진다', () {
      expect(blocks('- 위\n  - 아래\n    - 더 아래'), const [
        MarkdownList([
          MarkdownListItem(
            indent: 0,
            ordinal: null,
            checked: null,
            content: [MarkdownText('위')],
          ),
          MarkdownListItem(
            indent: 1,
            ordinal: null,
            checked: null,
            content: [MarkdownText('아래')],
          ),
          MarkdownListItem(
            indent: 2,
            ordinal: null,
            checked: null,
            content: [MarkdownText('더 아래')],
          ),
        ]),
      ]);
    });

    test('연속한 목록 줄은 한 블록으로 묶인다', () {
      expect(blocks('- 하나\n- 둘').length, 1);
      expect(blocks('- 하나\n\n- 둘').length, 2);
    });

    // 체크박스

    test('[ ] 와 [x] 는 체크 상태가 된다', () {
      expect(blocks('- [ ] 할 일\n- [x] 한 일\n- [X] 한 일'), const [
        MarkdownList([
          MarkdownListItem(
            indent: 0,
            ordinal: null,
            checked: false,
            content: [MarkdownText('할 일')],
          ),
          MarkdownListItem(
            indent: 0,
            ordinal: null,
            checked: true,
            content: [MarkdownText('한 일')],
          ),
          MarkdownListItem(
            indent: 0,
            ordinal: null,
            checked: true,
            content: [MarkdownText('한 일')],
          ),
        ]),
      ]);
    });

    test('목록이 아닌 줄의 [ ] 는 체크박스가 아니다', () {
      expect(blocks('[ ] 그냥 대괄호'), const [
        MarkdownParagraph([MarkdownText('[ ] 그냥 대괄호')]),
      ]);
    });

    // 코드블록

    test('펜스 코드블록은 언어와 내용을 그대로 담는다', () {
      expect(blocks('```swift\nlet x = 1\n\nlet y = 2\n```'), const [
        MarkdownCodeBlock(language: 'swift', code: 'let x = 1\n\nlet y = 2'),
      ]);
    });

    test('언어 표시가 없어도 코드블록이다', () {
      expect(blocks('```\nplain\n```'), const [
        MarkdownCodeBlock(language: null, code: 'plain'),
      ]);
    });

    /// 사용자가 아직 닫지 않은 채 미리보기를 켤 수 있다 — 그때 나머지 글이
    /// 통째로 사라지면 안 된다.
    test('닫히지 않은 펜스는 끝까지 코드블록이다', () {
      expect(blocks('```\n아직 쓰는 중'), const [
        MarkdownCodeBlock(language: null, code: '아직 쓰는 중'),
      ]);
    });

    test('코드블록 안의 마크다운 기호는 문법이 아니다', () {
      expect(blocks('```\n# 제목이 아니다\n- 목록도 아니다\n```'), const [
        MarkdownCodeBlock(language: null, code: '# 제목이 아니다\n- 목록도 아니다'),
      ]);
    });

    // 인용

    test('> 로 시작하는 줄은 인용이다', () {
      expect(blocks('> 인용문'), const [
        MarkdownQuote([
          MarkdownParagraph([MarkdownText('인용문')]),
        ]),
      ]);
    });

    /// 인용은 블록을 다시 품는다 — 안에 목록이나 제목이 들어가면 그대로 살아야 한다.
    test('인용 안에도 블록이 산다', () {
      expect(blocks('> # 제목\n> - 항목'), const [
        MarkdownQuote([
          MarkdownHeading(level: 1, content: [MarkdownText('제목')]),
          MarkdownList([
            MarkdownListItem(
              indent: 0,
              ordinal: null,
              checked: null,
              content: [MarkdownText('항목')],
            ),
          ]),
        ]),
      ]);
    });

    // 수평선

    test('---, ***, ___ 는 수평선이다', () {
      for (final source in ['---', '***', '___', '- - -', '*****']) {
        expect(blocks(source), const [MarkdownThematicBreak()], reason: source);
      }
    });

    test('두 개짜리는 수평선이 아니다', () {
      expect(blocks('--'), const [
        MarkdownParagraph([MarkdownText('--')]),
      ]);
    });

    // 줄바꿈 표기

    test('CRLF도 같은 결과를 낸다', () {
      expect(blocks('# 제목\r\n\r\n본문'), blocks('# 제목\n\n본문'));
    });
  });
}
