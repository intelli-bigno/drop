import XCTest

/// 탭 = 펼치기, 편집은 한 번 더 (BRU-77).
///
/// 이 규칙은 화면을 실제로 눌러 보지 않으면 확인할 방법이 없다 —
/// "탭하면 편집기가 열린다"가 오랫동안 아무 테스트에도 걸리지 않았던 이유다.
/// 앱은 `-dropPreview`로 띄운다(인메모리 표본, 네트워크 없음).
final class NoteViewerUITests: XCTestCase {
    private var app: XCUIApplication!

    /// 표본 노트 하나를 기준으로 삼는다 (`PreviewLaunch.sampleNotes`의 displayID 11).
    private let sampleNoteText = "장보기: 우유, 커피 원두, 사과"
    private let sampleNoteTitle = "#11"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-dropPreview"]
        app.launch()
    }

    private func waitForList() -> XCUIElement {
        let note = app.staticTexts[sampleNoteText]
        XCTAssertTrue(note.waitForExistence(timeout: 10), "목록이 뜨지 않았다")
        return note
    }

    /// 탭은 뷰어를 연다. **편집기가 열리면 안 된다** — 여는 순간 저장 경로가 붙는다(BRU-66).
    func testTapOpensViewerNotEditor() throws {
        waitForList().tap()

        let viewer = app.navigationBars[sampleNoteTitle]
        XCTAssertTrue(viewer.waitForExistence(timeout: 3), "탭해도 뷰어가 열리지 않았다")
        XCTAssertFalse(app.navigationBars["노트 편집"].exists, "탭만 했는데 편집기가 열렸다")

        // 뷰어에 있어야 하는 것들.
        XCTAssertTrue(app.buttons["편집"].exists, "뷰어에 편집 액션이 없다")
        // 댓글 버튼은 개수가 붙어 이름이 바뀐다("댓글 1개") — 식별자로 찾는다.
        XCTAssertTrue(app.buttons["댓글 열기"].exists, "뷰어에 댓글 진입이 없다")
        XCTAssertTrue(app.staticTexts[sampleNoteText].exists, "뷰어에 본문이 없다")
    }

    /// 편집기는 뷰어에서 한 번 더 눌러야 열린다.
    func testEditIsAnExplicitSecondStep() throws {
        waitForList().tap()

        let editButton = app.buttons["편집"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3), "뷰어에 편집 버튼이 없다")
        editButton.tap()

        XCTAssertTrue(
            app.navigationBars["노트 편집"].waitForExistence(timeout: 3),
            "편집을 눌러도 편집기가 열리지 않았다"
        )
    }

    /// 뷰어를 열었다 닫는 것만으로는 아무것도 바뀌지 않는다 — 목록의 본문이 그대로다.
    /// (DB 수준 불변은 별도 실측으로 본다. 여기서는 화면 왕복만 본다.)
    func testViewingAndClosingLeavesTheNoteAsItWas() throws {
        waitForList().tap()

        let viewer = app.navigationBars[sampleNoteTitle]
        XCTAssertTrue(viewer.waitForExistence(timeout: 3), "뷰어가 열리지 않았다")
        viewer.buttons["닫기"].tap()

        XCTAssertTrue(
            app.staticTexts[sampleNoteText].waitForExistence(timeout: 3),
            "뷰어를 닫고 오니 본문이 달라졌다"
        )
    }

    /// 선택 모드에서는 탭이 선택 토글이다 — 뷰어가 열리면 선택이 어긋난다.
    func testTapTogglesSelectionWhileSelecting() throws {
        let note = waitForList()
        note.press(forDuration: 1.0)

        XCTAssertTrue(
            app.navigationBars["1개 선택됨"].waitForExistence(timeout: 3),
            "롱프레스로 선택 모드에 들어가지 않았다"
        )

        note.tap()
        XCTAssertFalse(app.navigationBars[sampleNoteTitle].exists, "선택 모드인데 뷰어가 열렸다")
        XCTAssertTrue(
            app.navigationBars["DROP"].waitForExistence(timeout: 3),
            "탭으로 선택이 풀리지 않았다"
        )
    }

    /// 더블탭은 뷰어를 열지 않는다 — 싱글 탭만 펼치기다 (BRU-129 / BRU-77).
    func testDoubleTapDoesNotOpenViewer() throws {
        waitForList().doubleTap()

        XCTAssertFalse(
            app.navigationBars[sampleNoteTitle].waitForExistence(timeout: 1),
            "더블탭이 뷰어를 열었다"
        )
        XCTAssertFalse(app.navigationBars["노트 편집"].exists, "더블탭이 편집기를 열었다")
    }

    /// 선택 모드 더블탭은 복사 대신 토글만 — 뷰어가 열리면 선택이 깨진다.
    func testDoubleTapInSelectionDoesNotOpenViewer() throws {
        let note = waitForList()
        note.press(forDuration: 1.0)
        XCTAssertTrue(
            app.navigationBars["1개 선택됨"].waitForExistence(timeout: 3),
            "롱프레스로 선택 모드에 들어가지 않았다"
        )

        note.doubleTap()
        XCTAssertFalse(app.navigationBars[sampleNoteTitle].exists, "선택 모드 더블탭이 뷰어를 열었다")
    }
}
