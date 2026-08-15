import SwiftUI
import WidgetKit

/// 위젯 갤러리에 올라가는 것들.
///
/// Flutter 앱의 위젯(`apps/mobile/ios/DropWidget/`)에는 녹음·카메라·갤러리
/// 바로가기도 있었지만, 네이티브 앱에는 대응하는 딥링크가 없다 —
/// 없는 곳으로 보내는 버튼을 두지 않는다. 녹음은 BRU-48에서 앱에서도 없앴다.
@main
struct DropWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecentNotesWidget()
        QuickComposeWidget()
    }
}
