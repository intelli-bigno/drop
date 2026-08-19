import XCTest

/// 뷰어가 **DB를 건드리지 않는지** 실제 앱으로 확인하는 자리 (BRU-77).
///
/// 다른 UI 테스트는 `-dropPreview`(인메모리)로 돈다. 그것만으로는
/// "뷰어를 열었다 닫아도 `content`·`updated_at`이 그대로인가"를 확인할 수 없다 —
/// 저장이 일어나는 곳은 DB이기 때문이다. 그래서 여기서는 `-dropLocalSession`으로
/// **로컬 Supabase의 시드 사용자**(`supabase/seed.sql`)로 붙는다.
///
/// 이 테스트 자체는 DB를 읽지 않는다. 화면을 열었다 닫는 왕복만 만들고,
/// 그 앞뒤의 행 값 비교는 밖에서 psql로 한다:
///
/// ```
/// psql "$DB_URL" -c "select content, updated_at from notes where id='…101'"
/// make ios-uitest
/// psql "$DB_URL" -c "select content, updated_at from notes where id='…101'"
/// ```
///
/// 로컬 Supabase가 떠 있지 않으면 건너뛴다 — CI에는 로컬 DB가 없다.
final class NoteViewerDatabaseUITests: XCTestCase {
    /// `supabase/seed.sql`의 표본 노트. 다른 표본과 달리 답글이 딸려 있어
    /// 목록에서 눈에 잘 띈다.
    private let seededNoteText = "장보기: 우유, 커피 원두, 사과"

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try XCTSkipUnless(Self.isLocalSupabaseReachable(), "로컬 Supabase가 떠 있지 않다 — 건너뛴다")

        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-dropLocalSession"]
        app.launch()
    }

    func testOpeningAndClosingViewerTouchesNothing() throws {
        let note = app.staticTexts[seededNoteText]
        XCTAssertTrue(note.waitForExistence(timeout: 20), "로컬 DB의 노트가 목록에 뜨지 않았다")

        note.tap()

        // 뷰어가 열렸다 — 본문 전문이 보이고 편집은 아직 열리지 않았다.
        let editButton = app.buttons["편집"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "뷰어가 열리지 않았다")
        XCTAssertFalse(app.navigationBars["노트 편집"].exists, "탭만 했는데 편집기가 열렸다")

        // 열린 뷰어를 증거로 남긴다 — 실측 결과(“DB가 그대로였다”)만 남으면
        // 정작 무엇을 열어 놓고 잰 것인지가 사라진다.
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "노트 뷰어 (로컬 DB)"
        shot.lifetime = .keepAlways
        add(shot)

        // 잠깐 머물렀다 닫는다 — 뒤늦게 나가는 저장이 있다면 이 사이에 나간다.
        Thread.sleep(forTimeInterval: 3)
        app.buttons["닫기"].firstMatch.tap()

        XCTAssertTrue(
            app.staticTexts[seededNoteText].waitForExistence(timeout: 5),
            "목록으로 돌아오지 못했다"
        )
        // 목록이 다시 그려질 때까지 둔다(뒤따르는 요청이 있다면 여기서 나간다).
        Thread.sleep(forTimeInterval: 3)
    }

    private static func isLocalSupabaseReachable() -> Bool {
        var request = URLRequest(url: URL(string: "http://127.0.0.1:58321/rest/v1/")!)
        request.timeoutInterval = 2
        let semaphore = DispatchSemaphore(value: 0)
        var reachable = false
        URLSession.shared.dataTask(with: request) { _, response, _ in
            reachable = response != nil
            semaphore.signal()
        }.resume()
        _ = semaphore.wait(timeout: .now() + 5)
        return reachable
    }
}
