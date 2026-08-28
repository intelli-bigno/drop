import SwiftUI
import WidgetKit

/// 위젯 갤러리에 올라가는 것들. `apps/ios/DropWidget` 이식본 —
/// DropCore·DropUI 의존만 `DropShell/`의 이식 조각으로 바꿨다.
@main
struct DropWidgetBundle: WidgetBundle {
    var body: some Widget {
        RecentNotesWidget()
        QuickComposeWidget()
        CameraWidget()
        GalleryWidget()
    }
}
