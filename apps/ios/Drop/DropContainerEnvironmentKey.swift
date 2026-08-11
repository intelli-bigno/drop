import DropCore
import SwiftUI

/// 컨테이너를 SwiftUI 환경으로 흘려보낸다. 뷰는 전역 싱글턴을 찾지 않고
/// 환경에서 꺼내 쓰므로, 프리뷰나 테스트에서 다른 컨테이너로 바꿔 끼울 수 있다.
private struct DropContainerKey: EnvironmentKey {
    static let defaultValue: DropEnvironmentContainer? = nil
}

extension EnvironmentValues {
    var dropContainer: DropEnvironmentContainer? {
        get { self[DropContainerKey.self] }
        set { self[DropContainerKey.self] = newValue }
    }
}
