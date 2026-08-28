/// DropCore `SharedInboxTests.swift`의 「딥링크 해석」·`WidgetSnapshotTests.swift`의
/// 「위젯 딥링크」 스위트 포팅.
library;

import 'package:drop_core/drop_core.dart';
import 'package:test/test.dart';

void main() {
  group('딥링크 해석', () {
    test('노트 상세 링크를 읽는다', () {
      expect(
        DropLink.parse(Uri.parse('drop://note/abc-123')),
        const NoteLink('abc-123'),
      );
    });

    test('웹 링크도 같은 경로로 읽는다', () {
      expect(
        DropLink.parse(Uri.parse('https://drop.intellieffect.com/note/xyz')),
        const NoteLink('xyz'),
      );
    });

    test('새 노트 작성 링크를 읽는다', () {
      expect(
        DropLink.parse(Uri.parse('drop://compose?text=%EB%A9%94%EB%AA%A8')),
        const ComposeLink('메모'),
      );
    });

    test('본문 없는 작성 링크도 유효하다', () {
      expect(DropLink.parse(Uri.parse('drop://compose')), const ComposeLink());
    });

    // Google 로그인 콜백이 같은 경로로 들어온다. 여기서 삼키면 로그인이 끊긴다.
    test('모르는 링크는 null이다', () {
      expect(
        DropLink.parse(
          Uri.parse('com.googleusercontent.apps.123:/oauth2redirect'),
        ),
        isNull,
      );
      expect(DropLink.parse(Uri.parse('drop://알수없음')), isNull);
    });

    test('빈 노트 id는 받아들이지 않는다', () {
      expect(DropLink.parse(Uri.parse('drop://note/')), isNull);
    });

    test('카메라 링크를 읽는다', () {
      expect(DropLink.parse(Uri.parse('drop://camera')), const CameraLink());
    });

    test('갤러리 링크를 읽는다', () {
      expect(DropLink.parse(Uri.parse('drop://gallery')), const GalleryLink());
    });

    // 웹 링크로도 같은 곳으로 가야 한다 — 링크 해석 경로는 하나다.
    test('웹 링크로도 카메라·갤러리를 연다', () {
      expect(
        DropLink.parse(Uri.parse('https://drop.intellieffect.com/camera')),
        const CameraLink(),
      );
      expect(
        DropLink.parse(Uri.parse('https://drop.intellieffect.com/gallery')),
        const GalleryLink(),
      );
    });

    // 녹음 기능은 BRU-48에서 앱에서 제거됐다. 없는 곳으로 보내는 링크를 만들지 않는다.
    test('녹음 링크는 여전히 모르는 링크다', () {
      expect(DropLink.parse(Uri.parse('drop://record')), isNull);
    });

    // 다른 도메인의 웹 링크를 삼키면 엉뚱한 사이트가 앱을 연다.
    test('intellieffect.com 밖의 웹 링크는 모르는 링크다', () {
      expect(
        DropLink.parse(Uri.parse('https://example.com/note/xyz')),
        isNull,
      );
    });
  });

  group('위젯 딥링크', () {
    // 위젯 탭 → 앱의 기존 작성 경로. 새 라우팅을 만들지 않는다.
    test('빠른 작성 링크는 작성 화면으로 해석된다', () {
      expect(DropLink.parse(DropLink.quickComposeUri), const ComposeLink());
    });

    test('노트 줄을 누르면 그 노트로 간다', () {
      expect(
        DropLink.parse(DropLink.noteUri('abc-123')),
        const NoteLink('abc-123'),
      );
    });

    // 위젯이 여는 URL과 앱이 읽는 해석이 같은 곳에서 나오는지 확인한다 (BRU-43).
    test('카메라 바로가기 링크는 카메라로 해석된다', () {
      expect(DropLink.parse(DropLink.cameraUri), const CameraLink());
    });

    test('갤러리 바로가기 링크는 갤러리로 해석된다', () {
      expect(DropLink.parse(DropLink.galleryUri), const GalleryLink());
    });
  });
}
