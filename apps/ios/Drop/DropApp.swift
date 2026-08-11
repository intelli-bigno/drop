import DropCore
import SwiftUI

@main
struct DropApp: App {
    /// 구성이 잘못됐으면 여기서 즉시 멈춘다. 잘못된 구성으로 실행을 이어가면
    /// "로그인이 안 된다" 같은 엉뚱한 증상으로 나타나 원인 추적이 길어진다.
    private let container: DropEnvironmentContainer

    init() {
        do {
            container = try DropEnvironmentContainer.live()
        } catch {
            fatalError(
                """
                빌드 구성을 읽지 못했습니다: \(error)

                apps/ios/Config/Config-*.xcconfig 가 있는지 확인하세요.
                  make ios-config   # 환경변수로부터 생성
                자세한 내용은 apps/ios/README.md.
                """
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.dropContainer, container)
        }
    }
}
