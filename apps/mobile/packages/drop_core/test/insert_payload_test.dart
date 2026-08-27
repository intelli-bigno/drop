import 'package:drop_core/drop_core.dart';
import 'package:test/test.dart';

/// DropCore `InsertPayloadTests.swift` 포팅.
/// INSERT 정책이 `user_id = auth.uid()`를 요구하는데 `user_id`에는 기본값이 없다.
/// 즉 **클라이언트가 넣지 않으면 NULL이 들어가 RLS가 거부한다.**
/// "RLS가 알아서 채워준다"고 착각하기 쉬운 자리라 payload를 직접 못박는다.
void main() {
  group('INSERT payload', () {
    test('노트 생성 payload에 user_id가 들어간다', () {
      final payload =
          noteInsertPayload(content: '본문', parentId: null, userId: 'user-1');

      expect(payload['user_id'], 'user-1');
      expect(payload['content'], '본문');
      expect(payload['source'], 'mobile');
    });

    /// 답글도 같은 정책을 받는다.
    test('부모 노트 id는 있으면 함께 실린다', () {
      final payload =
          noteInsertPayload(content: '', parentId: 'n-1', userId: 'user-1');

      expect(payload['parent_id'], 'n-1');
    });

    test('태그 생성 payload에도 user_id가 들어간다', () {
      final payload = tagInsertPayload(
        name: '일',
        userId: 'user-1',
        lastUsedAt: DateTime.now(),
      );

      expect(payload['user_id'], 'user-1');
      expect(payload['name'], '일');
      expect(payload['last_used_at'], isNotNull);
    });

    /// snake_case 변환이 빠지면 서버가 컬럼을 못 찾아 조용히 실패한다.
    test('키는 전부 snake_case로 나간다', () {
      final payload =
          noteInsertPayload(content: '', parentId: 'p', userId: 'u');

      expect(payload.containsKey('parentId'), isFalse);
      expect(payload.containsKey('userId'), isFalse);
    });
  });
}
