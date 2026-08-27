import 'package:drop_core/drop_core.dart';
import 'package:test/test.dart';

/// DropCore `MarkdownEditorTests.swift` 포팅.
/// 작성 시트 툴바가 부르는 편집 명령. **화면이 아니라 여기가 정본이다** —
/// "어디에 무엇을 끼워 넣고 커서를 어디 두느냐"는 순수 계산이고,
/// 에뮬레이터 없이 검증되어야 툴바를 늘려도 무너지지 않는다 (BRU-37).
void main() {
  MarkdownEditingResult apply(
    MarkdownEditingCommand command,
    String text,
    EditorRange selection,
  ) =>
      MarkdownEditor.apply(command, text, selection);

  group('마크다운 편집 명령', () {
    // 강조 감싸기

    test('고른 글자를 굵게로 감싼다', () {
      final result =
          apply(MarkdownEditingCommand.bold, 'hello world', const EditorRange(6, 5));
      expect(result.text, 'hello **world**');
      expect(result.selection, const EditorRange(8, 5));
    });

    test('이미 굵은 글자를 다시 누르면 풀린다', () {
      final inner =
          apply(MarkdownEditingCommand.bold, '**world**', const EditorRange(2, 5));
      expect(inner.text, 'world');
      expect(inner.selection, const EditorRange(0, 5));

      final outer =
          apply(MarkdownEditingCommand.bold, '**world**', const EditorRange(0, 9));
      expect(outer.text, 'world');
      expect(outer.selection, const EditorRange(0, 5));
    });

    test('고른 글자가 없으면 기호만 넣고 그 사이에 커서를 둔다', () {
      final result =
          apply(MarkdownEditingCommand.bold, 'memo', const EditorRange(4, 0));
      expect(result.text, 'memo****');
      expect(result.selection, const EditorRange(6, 0));
    });

    test('기울임은 별표 하나로 감싼다', () {
      final result =
          apply(MarkdownEditingCommand.italic, 'hello', const EditorRange(0, 5));
      expect(result.text, '*hello*');
      expect(result.selection, const EditorRange(1, 5));
    });

    /// UTF-16 기준으로 세지 않으면 한글·이모지가 섞인 순간 커서가 글자 가운데로 간다.
    test('한글과 이모지가 섞여도 자리가 맞는다', () {
      const text = '메모 🍊 끝';
      final result =
          apply(MarkdownEditingCommand.bold, text, const EditorRange(0, 2));
      expect(result.text, '**메모** 🍊 끝');
      expect(result.selection, const EditorRange(2, 2));
    });

    // 코드

    test('한 줄을 고르면 인라인 코드가 된다', () {
      final result =
          apply(MarkdownEditingCommand.code, 'run make', const EditorRange(4, 4));
      expect(result.text, 'run `make`');
      expect(result.selection, const EditorRange(5, 4));
    });

    /// 여러 줄에 백틱 하나를 두르면 렌더가 깨진다 — 그 경우는 펜스가 답이다.
    test('여러 줄을 고르면 펜스 코드블록이 된다', () {
      final result =
          apply(MarkdownEditingCommand.code, 'a\nb', const EditorRange(0, 3));
      expect(result.text, '```\na\nb\n```');
      expect(result.selection, const EditorRange(4, 3));
    });

    // 링크

    test('고른 글자가 링크 글자가 되고 주소 자리가 선택된다', () {
      final result =
          apply(MarkdownEditingCommand.link, 'drop', const EditorRange(0, 4));
      expect(result.text, '[drop](url)');
      expect(result.selection, const EditorRange(7, 3));
    });

    test('고른 글자가 없으면 글자 자리를 먼저 선택한다', () {
      final result =
          apply(MarkdownEditingCommand.link, '', const EditorRange(0, 0));
      expect(result.text, '[텍스트](url)');
      expect(result.selection, const EditorRange(1, 3));
    });

    // 줄 앞머리 — 제목

    test('제목은 눌릴 때마다 단계가 깊어진다', () {
      final first =
          apply(MarkdownEditingCommand.heading, 'memo', const EditorRange(4, 0));
      expect(first.text, '# memo');
      expect(first.selection, const EditorRange(6, 0));

      expect(
        apply(MarkdownEditingCommand.heading, '# memo', const EditorRange(6, 0))
            .text,
        '## memo',
      );
    });

    test('여섯 단계 다음에는 제목이 풀린다', () {
      expect(
        apply(MarkdownEditingCommand.heading, '###### memo',
                const EditorRange(0, 0))
            .text,
        'memo',
      );
    });

    // 줄 앞머리 — 목록·체크박스·인용

    test('불릿은 붙었다 떨어진다', () {
      final on =
          apply(MarkdownEditingCommand.bulletList, 'memo', const EditorRange(0, 0));
      expect(on.text, '- memo');
      expect(
        apply(MarkdownEditingCommand.bulletList, '- memo',
                const EditorRange(0, 0))
            .text,
        'memo',
      );
    });

    test('불릿을 떼면 체크박스까지 함께 떨어진다', () {
      expect(
        apply(MarkdownEditingCommand.bulletList, '- [ ] memo',
                const EditorRange(0, 0))
            .text,
        'memo',
      );
    });

    test('이미 불릿인 줄에는 체크칸만 끼워 넣는다', () {
      expect(
        apply(MarkdownEditingCommand.checkbox, '- memo', const EditorRange(0, 0))
            .text,
        '- [ ] memo',
      );
    });

    test('맨 줄에 체크박스를 누르면 불릿까지 붙는다', () {
      expect(
        apply(MarkdownEditingCommand.checkbox, 'memo', const EditorRange(0, 0))
            .text,
        '- [ ] memo',
      );
    });

    test('체크박스를 다시 누르면 통째로 떨어진다', () {
      expect(
        apply(MarkdownEditingCommand.checkbox, '- [x] memo',
                const EditorRange(0, 0))
            .text,
        'memo',
      );
    });

    test('인용도 붙었다 떨어진다', () {
      expect(
        apply(MarkdownEditingCommand.quote, 'memo', const EditorRange(0, 0)).text,
        '> memo',
      );
      expect(
        apply(MarkdownEditingCommand.quote, '> memo', const EditorRange(0, 0))
            .text,
        'memo',
      );
    });

    // 여러 줄에 걸친 앞머리

    test('고른 범위에 걸친 줄 전부에 앞머리가 붙는다', () {
      final result = apply(
          MarkdownEditingCommand.bulletList, 'a\nb\nc', const EditorRange(0, 3));
      expect(result.text, '- a\n- b\nc');
    });

    /// 일부만 붙어 있을 때 "떼기"로 판정하면 나머지 줄이 영영 목록이 되지 못한다.
    test('전부 붙어 있을 때만 떨어진다', () {
      expect(
        apply(MarkdownEditingCommand.bulletList, '- a\nb', const EditorRange(0, 5))
            .text,
        '- - a\n- b',
      );
      expect(
        apply(MarkdownEditingCommand.bulletList, '- a\n- b',
                const EditorRange(0, 7))
            .text,
        'a\nb',
      );
    });

    test('앞머리를 붙여도 고른 글자는 그대로 고른 채 남는다', () {
      final result = apply(
          MarkdownEditingCommand.bulletList, 'memo', const EditorRange(0, 4));
      expect(result.text, '- memo');
      expect(result.selection, const EditorRange(2, 4));
    });

    // 원문 보존 (BRU-66)

    /// 명령을 부른 적이 없으면 글자는 한 자도 달라지지 않는다. 미리보기 전환이
    /// 저장 경로를 건드리지 않는다는 불변식의 핵심이 이것이다.
    test('명령은 원래 문자열을 바꾸지 않는다', () {
      const original = '# 제목\n- [ ] 할 일';
      apply(MarkdownEditingCommand.bold, original, const EditorRange(0, 3));
      expect(original, '# 제목\n- [ ] 할 일');
    });
  });
}
