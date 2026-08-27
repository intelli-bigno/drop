import 'package:drop_core/drop_core.dart';
import 'package:test/test.dart';

/// DropCore `MarkdownInlineTests.swift` 포팅.
/// 인라인 문법. 블록 파서와 갈라 두는 이유는 하나 — 인라인 규칙은 경계 조건이
/// 많아서(닫히지 않은 마커, 이스케이프, 코드 스팬) 따로 조여야 한다.
void main() {
  const parser = MarkdownParser();

  /// 문단 하나로 감싸 인라인 결과만 꺼낸다.
  List<MarkdownInline> inlines(String source) {
    final first = parser.parse(source).blocks.firstOrNull;
    if (first is! MarkdownParagraph) return const [];
    return first.content;
  }

  group('마크다운 파서 — 인라인', () {
    // 강조

    test('**과 __는 굵게다', () {
      expect(inlines('앞 **굵게** 뒤'), const [
        MarkdownText('앞 '),
        MarkdownStrong([MarkdownText('굵게')]),
        MarkdownText(' 뒤'),
      ]);
      expect(inlines('__굵게__'), const [
        MarkdownStrong([MarkdownText('굵게')]),
      ]);
    });

    test('*과 _는 기울임이다', () {
      expect(inlines('*기울임*'), const [
        MarkdownEmphasis([MarkdownText('기울임')]),
      ]);
      expect(inlines('_기울임_'), const [
        MarkdownEmphasis([MarkdownText('기울임')]),
      ]);
    });

    /// `snake_case_name`이 기울임이 되면 코드 이름을 적은 노트가 전부 뭉개진다.
    test('단어 안의 _는 기울임이 아니다', () {
      expect(inlines('snake_case_name'), const [
        MarkdownText('snake_case_name'),
      ]);
    });

    test('굵게 안에 기울임이 들어간다', () {
      expect(inlines('**굵고 *기울고***'), const [
        MarkdownStrong([
          MarkdownText('굵고 '),
          MarkdownEmphasis([MarkdownText('기울고')]),
        ]),
      ]);
    });

    test('닫히지 않은 마커는 글자 그대로다', () {
      expect(inlines('**닫지 않음'), const [MarkdownText('**닫지 않음')]);
      expect(inlines('한 개 * 별'), const [MarkdownText('한 개 * 별')]);
    });

    // 코드 스팬

    test('백틱 사이는 인라인 코드다', () {
      expect(inlines('값은 `let x = 1` 이다'), const [
        MarkdownText('값은 '),
        MarkdownCode('let x = 1'),
        MarkdownText(' 이다'),
      ]);
    });

    test('코드 스팬 안의 마크업은 글자 그대로다', () {
      expect(inlines('`**굵지 않다**`'), const [MarkdownCode('**굵지 않다**')]);
    });

    // 링크

    test('[텍스트](주소)는 링크다', () {
      expect(inlines('[드롭](https://drop.example)'), const [
        MarkdownLink(
          content: [MarkdownText('드롭')],
          destination: 'https://drop.example',
        ),
      ]);
    });

    test('링크 글자 안의 강조도 산다', () {
      expect(inlines('[**굵은 링크**](https://x)'), const [
        MarkdownLink(
          content: [
            MarkdownStrong([MarkdownText('굵은 링크')]),
          ],
          destination: 'https://x',
        ),
      ]);
    });

    test('주소 뒤의 제목은 버린다', () {
      expect(inlines('[글](https://x "제목")'), const [
        MarkdownLink(content: [MarkdownText('글')], destination: 'https://x'),
      ]);
    });

    test('괄호가 없으면 링크가 아니다', () {
      expect(inlines('[그냥 대괄호]'), const [MarkdownText('[그냥 대괄호]')]);
    });

    // 이스케이프

    test('역슬래시는 다음 기호를 글자로 만든다', () {
      expect(inlines('\\*별표\\*'), const [MarkdownText('*별표*')]);
      expect(inlines('2 \\* 3'), const [MarkdownText('2 * 3')]);
    });

    /// 강조가 아닌 곳의 역슬래시까지 먹어 버리면 윈도우 경로가 사라진다.
    test('기호가 아닌 글자 앞의 역슬래시는 남는다', () {
      expect(inlines('C:\\Users'), const [MarkdownText('C:\\Users')]);
    });
  });
}
