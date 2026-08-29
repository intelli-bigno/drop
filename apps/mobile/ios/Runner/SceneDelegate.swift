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

  /// 콜드 스타트 딥링크를 플러그인에게 다시 흘린다 (BRU-188).
  ///
  /// 앱이 꺼져 있을 때 위젯을 누르면 URL은 `scene:openURLContexts:`가 아니라 **여기**로만
  /// 온다(`connectionOptions.urlContexts`). Flutter의 씬 브리지는 그 초기 URL을
  /// `addApplicationDelegate` 계열 플러그인에게 전달하지 않아서, `app_links`가 링크를
  /// 통째로 못 받는다 — 실측: 앱이 떠 있을 때 `drop://note/5`는 뷰어를 열지만,
  /// 종료 상태에서 같은 링크를 열면 홈 목록만 뜬다.
  ///
  /// `super`가 엔진·플러그인 등록을 마친 뒤에 `scene:openURLContexts:` 경로로 되돌린다.
  /// 중복 전달이 되더라도 `DeepLinkRouter`는 같은 링크를 다시 보관할 뿐이라 무해하다.
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    let contexts = connectionOptions.urlContexts
    guard !contexts.isEmpty else { return }
    DispatchQueue.main.async { [weak self] in
      self?.scene(scene, openURLContexts: contexts)
    }
  }
}
