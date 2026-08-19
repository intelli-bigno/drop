// swift-tools-version: 6.2
import PackageDescription

/// 화면 간에 공유되는 뷰와 디자인 토큰.
///
/// SwiftUI에 의존해도 되는 유일한 패키지다. 도메인 로직은 DropCore에 둔다.
let package = Package(
    name: "DropUI",
    // Liquid Glass API가 iOS 26부터라 앱과 같은 타깃으로 올렸다 (BRU-75).
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "DropUI", targets: ["DropUI"]),
    ],
    dependencies: [
        .package(path: "../DropCore"),
    ],
    targets: [
        .target(name: "DropUI", dependencies: ["DropCore"]),
    ]
)
