import XCTest

/// 화면을 실제로 조작해 보는 유일한 검증 (BRU-78).
///
/// 도메인 로직은 `DropCore` 테스트가 시뮬레이터 없이 덮는다. 여기서 보는 것은
/// **손가락이 닿는 부분**뿐이다 — 스와이프가 뜨는지, 버튼이 눌리는지, 시트가 열리는지.
/// 그 구간은 지금까지 "빌드가 됐다"까지만 확인되고 있었다 (BRU-69에서 답글
/// 스와이프를 붙여 놓고 당겨 보지 못한 채 머지한 것이 계기다).
///
/// 앱은 `-dropPreview`로 띄운다 — 인메모리 표본이라 자격증명도 네트워크도 필요 없다.
final class ReplyFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-dropPreview"]
        app.launch()
    }

    /// 목록이 뜨기까지 기다린다. 표본 노트 하나를 기준으로 삼는다.
    private func waitForList() -> XCUIElement {
        let note = app.staticTexts["장보기: 우유, 커피 원두, 사과"]
        XCTAssertTrue(note.waitForExistence(timeout: 10), "목록이 뜨지 않았다")
        return note
    }

    func testSwipeRevealsReplyActionAndOpensComposer() throws {
        let note = waitForList()

        // 왼쪽에서 오른쪽으로 당기면 댓글·답글이 나온다 (오른쪽은 삭제·고정).
        note.swipeRight()

        let replyButton = app.buttons["답글"]
        XCTAssertTrue(replyButton.waitForExistence(timeout: 3), "스와이프해도 답글 액션이 없다")

        replyButton.tap()

        // 답글 시트는 새 노트 시트와 생김새가 같다 — 제목으로만 구분된다.
        let title = app.navigationBars.staticTexts.element(matching: NSPredicate(format: "label BEGINSWITH %@", "답글"))
        XCTAssertTrue(title.waitForExistence(timeout: 3), "답글 컴포저가 열리지 않았다")
    }

    /// 답글 스와이프가 댓글 스와이프를 밀어내지 않았는지 — 같은 방향에 둘이 함께 있다.
    func testCommentActionStillReachable() throws {
        let note = waitForList()

        note.swipeRight()

        XCTAssertTrue(app.buttons["댓글"].waitForExistence(timeout: 3), "댓글 액션이 사라졌다")
        XCTAssertTrue(app.buttons["답글"].exists, "답글 액션이 사라졌다")
    }
}
