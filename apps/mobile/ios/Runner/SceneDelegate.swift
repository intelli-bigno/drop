import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  /// 씬 상태 복원을 명시적으로 끈다 (BRU-178).
  ///
  /// DROP은 노트를 서버(Supabase)에 두고 앱을 켤 때마다 처음부터 그리므로 씬 단위
  /// 상태 복원이 필요 없다. 반면 이 경로는 iOS 26에서 실제로 앱을 죽인다 —
  /// `FlutterSceneDelegate`의 기본 구현이 `FlutterPluginSceneLifeCycleDelegate`를 거쳐
  /// `NSUserActivity`를 만드는데, iOS 26의 UserActivity 프레임워크가 그 타입 문자열을
  /// 거부하고 `NSException`을 던진다(실측 스택: `-[UAUserActivity
  /// initWithTypeIdentifier:suggestedActionType:options:]` → `objc_exception_throw`).
  /// Flutter의 씬 상태 복원은 아직 미구현이기도 하다 (flutter/flutter#174402).
  ///
  /// nil을 돌려주면 UIKit은 저장할 것이 없다고 보고 그냥 넘어간다.
  override func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
    return nil
  }
}
