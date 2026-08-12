import Foundation
import Testing

@testable import DropCore

/// INSERT 정책이 `user_id = auth.uid()`를 요구하는데 `user_id`에는 기본값이 없다.
/// 즉 **클라이언트가 넣지 않으면 NULL이 들어가 RLS가 거부한다.**
/// "RLS가 알아서 채워준다"고 착각하기 쉬운 자리라 payload를 직접 못박는다.
@Suite("INSERT payload")
struct InsertPayloadTests {
    private func json(_ value: some Encodable) throws -> [String: Any] {
        let data = try DropJSON.encoder.encode(value)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test("노트 생성 payload에 user_id가 들어간다")
    func noteInsertCarriesUserID() throws {
        let payload = try json(NoteInsert(content: "본문", parentID: nil, userID: "user-1"))

        #expect(payload["user_id"] as? String == "user-1")
        #expect(payload["content"] as? String == "본문")
        #expect(payload["source"] as? String == "mobile")
    }

    /// 답글도 같은 정책을 받는다.
    @Test("부모 노트 id는 있으면 함께 실린다")
    func noteInsertCarriesParent() throws {
        let payload = try json(NoteInsert(content: "", parentID: "n-1", userID: "user-1"))

        #expect(payload["parent_id"] as? String == "n-1")
    }

    @Test("태그 생성 payload에도 user_id가 들어간다")
    func tagInsertCarriesUserID() throws {
        let payload = try json(TagInsert(name: "일", userID: "user-1", lastUsedAt: Date()))

        #expect(payload["user_id"] as? String == "user-1")
        #expect(payload["name"] as? String == "일")
        #expect(payload["last_used_at"] != nil)
    }

    /// snake_case 변환이 빠지면 서버가 컬럼을 못 찾아 조용히 실패한다.
    @Test("키는 전부 snake_case로 나간다")
    func keysAreSnakeCase() throws {
        let payload = try json(NoteInsert(content: "", parentID: "p", userID: "u"))

        #expect(payload["parentId"] == nil)
        #expect(payload["userId"] == nil)
    }
}
