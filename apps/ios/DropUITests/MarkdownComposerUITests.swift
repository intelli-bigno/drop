import XCTest

/// 마크다운 편집기·뷰어를 실제로 눌러 보는 검증 (BRU-37).
///
/// 문법 해석은 `DropCore`의 파서 테스트가 시뮬레이터 없이 덮는다. 여기서 보는 것은
/// **화면에 실제로 그렇게 그려지느냐**다 — 카드가 기호를 벗은 한 줄인지, 미리보기가
/// 제목·목록·인용을 세우는지, 툴바가 원문에 기호를 넣는지.
///
/// 앱은 `-dropPreview`로 띄운다 — 인메모리 표본이라 자격증명도 네트워크도 필요 없다.
final class MarkdownComposerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-dropPreview"]
        app.launch()
    }

    /// 마크다운 표본 노트의 목록 행.
    private func markdownRow() -> XCUIElement {
        let row = app.staticTexts.element(
            matching: NSPredicate(format: "label BEGINSWITH %@", "이번 주 정리")
        )
        XCTAssertTrue(row.waitForExistence(timeout: 10), "목록이 뜨지 않았다")
        return row
    }

    /// 행을 눌러 **뷰어**를 연 뒤, 거기서 "편집"을 한 번 더 눌러 컴포저를 연다.
    ///
    /// 예전에는 행 탭이 곧 컴포저였다. BRU-77이 그 탭을 읽기 전용 뷰어로 바꿨다 —
    /// 열어 보려던 동작이 저장 경로를 건드리면 안 되기 때문이다(BRU-66).
    /// 편집기로 가는 길은 이제 이 두 걸음뿐이다.
    private func openComposer() -> XCUIElement {
        markdownRow().tap()

        // 뷰어가 떴다는 증거이자 다음 걸음. 이 시점에는 컴포저가 아직 없으므로
        // "편집"이라는 이름을 가진 버튼은 뷰어의 것 하나뿐이다.
        let edit = app.buttons["편집"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5), "탭해도 뷰어가 열리지 않았다")
        XCTAssertFalse(app.navigationBars["노트 편집"].exists, "탭만 했는데 편집기가 열렸다")
        edit.tap()

        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 3), "컴포저가 열리지 않았다")
        return editor
    }

    /// 목록은 한 줄만 보여 준다(BRU-49). 원문을 그대로 태우면 `##`·`**`가
    /// 그 한 줄의 절반을 먹는다.
    func testListRowShowsMarkupFreeSingleLine() throws {
        let label = markdownRow().label
        XCTAssertFalse(label.contains("#"), "카드에 제목 기호가 남아 있다: \(label)")
        XCTAssertFalse(label.contains("**"), "카드에 강조 기호가 남아 있다: \(label)")
        XCTAssertFalse(label.contains("\n"), "카드가 한 줄이 아니다: \(label)")
    }

    /// 편집기는 원문을 그대로 연다 — 저장 형식은 평문 마크다운 그대로다.
    func testComposerOpensRawMarkdown() throws {
        let value = openComposer().value as? String ?? ""
        XCTAssertTrue(value.hasPrefix("# 이번 주 정리"), "원문이 아니다: \(value.prefix(40))")
        XCTAssertTrue(value.contains("- [x] 파서를 DropCore에 두기"), "체크박스 원문이 사라졌다")
    }

    func testPreviewRendersBlocks() throws {
        _ = openComposer()
        app.buttons["미리보기 전환"].tap()

        // 제목은 기호 없이 글자만 선다.
        XCTAssertTrue(app.staticTexts["이번 주 정리"].waitForExistence(timeout: 3), "제목이 렌더되지 않았다")
        XCTAssertTrue(app.staticTexts["뷰어 붙이기"].exists, "체크박스 항목이 렌더되지 않았다")
        XCTAssertTrue(app.staticTexts["저장 형식은 평문 마크다운 그대로다."].exists, "인용이 렌더되지 않았다")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "미리보기 렌더"
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// **열람만 해서는 본문이 바뀌지 않는다** (BRU-66). 미리보기 전환은 화면
    /// 상태만 건드리고 원문도 저장 경로도 손대지 않는다.
    func testPreviewRoundTripLeavesSourceUntouched() throws {
        let before = openComposer().value as? String

        app.buttons["미리보기 전환"].tap()
        XCTAssertTrue(app.staticTexts["이번 주 정리"].waitForExistence(timeout: 3), "미리보기로 넘어가지 않았다")
        // 같은 버튼이다 — 이름만 "편집"으로 바뀐다. 뷰어의 "편집"과 겹치므로
        // 이름이 아니라 식별자로 잡는다.
        app.buttons["미리보기 전환"].tap()

        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 3), "편집으로 돌아오지 않았다")
        XCTAssertEqual(before, editor.value as? String, "미리보기를 다녀왔더니 원문이 달라졌다")
    }

    /// 툴바가 실제로 원문에 기호를 넣는지 — 모바일 키보드에서 `- [ ]`를 손으로
    /// 치게 두면 마크다운은 아무도 안 쓰는 기능이 된다.
    func testToolbarInsertsCheckboxMarker() throws {
        _ = markdownRow()
        app.buttons["plus"].tap()

        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 3), "새 노트 시트가 열리지 않았다")

        app.buttons["체크박스"].tap()

        let value = editor.value as? String ?? ""
        XCTAssertTrue(value.contains("- [ ]"), "체크박스 기호가 들어가지 않았다: \(value)")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "편집기 툴바"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
