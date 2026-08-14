import DropCore
import WidgetKit

/// 위젯이 읽을 요약을 App Group에 적어 두고, 위젯을 다시 그리게 한다.
///
/// 위젯 확장은 Supabase 세션을 갖지 못하므로 스스로 노트를 못 읽는다.
/// 목록을 이미 들고 있는 앱이 대신 적어 주는 것이 유일한 경로다.
/// 무엇을 적을지 고르는 규칙은 `WidgetSnapshot`(DropCore)에 있고 테스트가 덮는다.
enum WidgetSnapshotPublisher {
    static func publish(notes: [Note]) {
        guard let store = WidgetSnapshotStore() else { return }
        // 실패해도 앱은 그대로 간다 — 위젯이 한 박자 늦게 갱신될 뿐이다.
        try? store.write(WidgetSnapshot(from: notes))
        WidgetCenter.shared.reloadAllTimelines()
    }
}
