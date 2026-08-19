// swift-tools-version: 6.2
import PackageDescription

/// DROP의 도메인 로직 계층.
///
/// 이 패키지는 UIKit / SwiftUI에 의존하지 않는다. 시뮬레이터 없이 `swift test`로
/// 검증되는 상태를 유지하는 것이 레포의 TDD 사이클을 지탱하는 조건이다.
let package = Package(
    name: "DropCore",
    // iOS 타깃은 앱과 맞춘다 (BRU-75). macOS는 `swift test`가 도는 자리라
    // iOS 상향과 무관하게 그대로 둔다 — 이 패키지는 UIKit / SwiftUI를 쓰지 않는다.
    platforms: [.iOS(.v26), .macOS(.v14)],
    products: [
        .library(name: "DropCore", targets: ["DropCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.54.1"),
    ],
    targets: [
        .target(
            name: "DropCore",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
            ]
        ),
        .testTarget(name: "DropCoreTests", dependencies: ["DropCore"]),
    ]
)
