import SwiftUI
import WidgetKit

/// 위젯 갤러리에 올라가는 것들.
///
/// Flutter 앱의 위젯(`apps/mobile/ios/DropWidget/`)에 있던 카메라·갤러리
/// 바로가기는 BRU-43에서 딥링크(`drop://camera` · `drop://gallery`)를 만들며 돌아왔다.
/// 녹음 바로가기는 만들지 않는다 — 녹음 기능 자체가 BRU-48에서 없어졌고,
/// **없는 곳으로 보내는 버튼을 두지 않는다**는 규칙은 그대로다.
@main
struct DropWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecentNotesWidget()
        QuickComposeWidget()
        CameraWidget()
        GalleryWidget()
    }
}
