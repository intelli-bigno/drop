import Foundation
import Testing

/// 화면 코드가 디자인 규칙을 지키는지 **소스를 읽어서** 검증한다 (BRU-75).
///
/// 여기가 도메인 로직이 아닌 것은 안다. 그럼에도 DropCore 테스트에 두는 이유는
/// 하나 — `make ios-test`가 도는 곳이 여기뿐이고, 시뮬레이터 없이 도는 빠른
/// 피드백이 이 레포 TDD 사이클의 전제이기 때문이다. 색 규칙을 눈으로만 지키면
/// 다음 화면이 추가되는 순간 조용히 무너진다.
@Suite("디자인 시스템 감사")
struct DesignSystemAuditTests {
    /// `apps/ios`. 이 파일 위치에서 거슬러 올라간다 —
    /// `swift test`의 작업 디렉토리는 호출 위치에 따라 달라져 믿을 수 없다.
    private static let iosRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // DropCoreTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // DropCore
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // apps/ios

    /// 화면을 그리는 소스 전부. 앱·위젯·공유 확장·공유 뷰 패키지가 같은 팔레트를 봐야 한다.
    private static let viewSourceDirectories = [
        "Drop",
        "DropWidget",
        "DropShare",
        "Packages/DropUI/Sources/DropUI",
    ]

    /// 색 리터럴이 허용되는 유일한 두 파일.
    /// `DropTokens.swift`는 생성물(SoT = design-system/drop/tokens.json)이고,
    /// `DropTheme.swift`는 그 위에 뜻을 입히는 의미 계층이다.
    private static let paletteDefinitionFiles: Set<String> = [
        "DropTokens.swift",
        "DropTheme.swift",
    ]

    // MARK: - 팔레트

    /// 시스템 기본색은 웜 페이퍼 팔레트가 아니다. 하나라도 남으면 그 화면만
    /// 시스템 외양으로 되돌아가 앱의 색이 갈라진다.
    @Test("화면 코드에 시스템 기본색이 남아 있지 않다")
    func noSystemDefaultColorsInViews() throws {
        let banned = [
            "Color.primary", "Color.secondary", "Color.accentColor",
            "Color.white", "Color.black", "Color.gray",
            "Color.red", "Color.orange", "Color.yellow",
            "Color.green", "Color.blue", "Color.indigo", "Color.purple",
            "foregroundStyle(.primary", "foregroundStyle(.secondary",
            "foregroundStyle(.tertiary", "foregroundStyle(.quaternary",
            "foregroundStyle(.white", "foregroundStyle(.black",
            "foregroundStyle(.red", "foregroundStyle(.orange",
            "foregroundStyle(.blue", "foregroundStyle(.tint",
            "foregroundColor(",
            "tint(.orange", "tint(.blue", "tint(.indigo",
            "tint(.white", "tint(.red", "tint(.green",
            ".systemBackground",
            "background(.bar", "background(.black",
            ".fill.tertiary",
        ]

        let offenders = try Self.findOccurrences(of: banned, skippingFiles: Self.paletteDefinitionFiles)
        #expect(offenders.isEmpty, "시스템 기본색 잔존:\n\(offenders.joined(separator: "\n"))")
    }

    // MARK: - Liquid Glass

    /// **유리는 기능 레이어(툴바·내비게이션·FAB·시트)에만 쓴다.**
    /// 콘텐츠는 종이여야 한다 — 노트 본문이 유리 위에 뜨면 뒤에 흐르는 것이
    /// 비쳐 글자가 읽히지 않는다. 목록 행과 첨부 썸네일이 그 콘텐츠다.
    @Test("콘텐츠 레이어에는 유리를 쓰지 않는다")
    func noGlassOnContentLayers() throws {
        let contentFiles = [
            "Packages/DropUI/Sources/DropUI/NoteCard.swift",
            "Packages/DropUI/Sources/DropUI/AttachmentThumbnail.swift",
        ]
        let glass = ["glassEffect", "buttonStyle(.glass", "GlassEffectContainer"]

        var offenders: [String] = []
        for relativePath in contentFiles {
            let url = Self.iosRoot.appending(path: relativePath)
            let source = try String(contentsOf: url, encoding: .utf8)
            for (index, line) in Self.effectiveLines(of: source) {
                for needle in glass where line.contains(needle) {
                    offenders.append("\(relativePath):\(index) — \(needle)")
                }
            }
        }
        #expect(offenders.isEmpty, "콘텐츠에 유리가 붙었다:\n\(offenders.joined(separator: "\n"))")
    }

    /// 유리가 실제로 채택돼 있는지도 본다 — 금지 규칙만 있으면
    /// "아무 데도 안 쓰기"로도 통과해 버린다.
    @Test("기능 레이어는 유리를 쓴다")
    func glassIsAdoptedOnChrome() throws {
        let chrome = [
            "Drop/HomeView.swift", // 작성 FAB
            "Drop/NoteFilterBar.swift", // 목록 위에 뜨는 필터 줄
            "Drop/SelectionActionBar.swift", // 선택 모드 하단 바
            "Drop/NoteComposerSheet.swift", // 키보드 위 닫기·미리보기·추가
        ]
        for relativePath in chrome {
            let url = Self.iosRoot.appending(path: relativePath)
            let source = try String(contentsOf: url, encoding: .utf8)
            let hasGlass = Self.effectiveLines(of: source).contains { _, line in
                line.contains("glassEffect") || line.contains("buttonStyle(.glass")
            }
            #expect(hasGlass, "\(relativePath)에 Liquid Glass가 없다")
        }
    }

    // MARK: - 구 외양 강제 플래그

    /// `UIDesignRequiresCompatibility`가 켜져 있으면 iOS 26 SDK로 빌드해도
    /// 시스템이 옛 외양을 그린다 — 유리가 통째로 죽는다.
    @Test("구 외양 강제 플래그가 켜져 있지 않다")
    func noLegacyAppearanceOptOut() throws {
        for target in ["Drop", "DropWidget", "DropShare"] {
            let url = Self.iosRoot.appending(path: "\(target)/Info.plist")
            let plist = try String(contentsOf: url, encoding: .utf8)
            #expect(
                !plist.contains("UIDesignRequiresCompatibility"),
                "\(target)/Info.plist에 UIDesignRequiresCompatibility가 있다"
            )
        }
    }

    // MARK: - 배포 타깃

    /// 유리 API는 iOS 26부터다. 배포 타깃이 낮으면 `if #available` 분기가
    /// 되살아나 코드가 두 갈래로 갈린다 — BRU-75에서 (b)로 확정한 것을 지킨다.
    @Test("배포 타깃이 iOS 26이다")
    func deploymentTargetIsIOS26() throws {
        let projectYML = try String(
            contentsOf: Self.iosRoot.appending(path: "project.yml"),
            encoding: .utf8
        )
        #expect(projectYML.contains("iOS: \"26.0\""), "project.yml 배포 타깃이 iOS 26이 아니다")

        for package in ["DropCore", "DropUI"] {
            let manifest = try String(
                contentsOf: Self.iosRoot.appending(path: "Packages/\(package)/Package.swift"),
                encoding: .utf8
            )
            #expect(manifest.contains(".iOS(.v26)"), "\(package)의 iOS 플랫폼이 v26이 아니다")
        }
    }

    // MARK: - 도구

    /// 주석은 검사 대상이 아니다 — 규칙을 설명하는 문장에 금지어가 들어 있는 것이
    /// 위반으로 잡히면 주석을 못 쓰게 된다.
    private static func effectiveLines(of source: String) -> [(Int, Substring)] {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .map { index, line in
                let code = line.range(of: "//").map { line[line.startIndex ..< $0.lowerBound] } ?? line
                return (index + 1, code)
            }
    }

    private static func findOccurrences(
        of needles: [String],
        skippingFiles skipped: Set<String>
    ) throws -> [String] {
        var offenders: [String] = []
        for directory in viewSourceDirectories {
            let root = iosRoot.appending(path: directory)
            guard let walker = FileManager.default.enumerator(atPath: root.path) else { continue }
            for case let relative as String in walker where relative.hasSuffix(".swift") {
                let name = (relative as NSString).lastPathComponent
                guard !skipped.contains(name) else { continue }
                let source = try String(contentsOf: root.appending(path: relative), encoding: .utf8)
                for (index, line) in effectiveLines(of: source) {
                    for needle in needles where line.contains(needle) {
                        offenders.append("\(directory)/\(relative):\(index) — \(needle)")
                    }
                }
            }
        }
        return offenders.sorted()
    }
}
