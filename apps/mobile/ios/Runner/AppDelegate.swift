import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// 우리가 되찾아온 씬 델리게이트들. `UIScene.delegate`는 weak이므로 여기서 잡아둔다.
  private var adoptedSceneDelegates: [SceneDelegate] = []
  private var sceneObserver: NSObjectProtocol?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    sceneObserver = NotificationCenter.default.addObserver(
      forName: UIScene.willConnectNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let scene = notification.object as? UIWindowScene else { return }
      self?.adoptSceneIfForeign(scene)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// 남의 앱이 남긴 씬 세션을 우리 것으로 되찾아온다 (BRU-178).
  ///
  /// iOS는 `UISceneSession`을 **씬 델리게이트 클래스까지 통째로 디스크에 영속화**하고,
  /// 같은 번들 ID로 앱을 덮어 설치해도 그 세션을 그대로 되살린다. DROP은 번들 ID
  /// `com.intellieffect.drop.mobile` 하나를 SwiftUI 네이티브 앱(`apps/ios`,
  /// `@main struct DropApp: App`)과 이 Flutter 앱이 번갈아 써 왔다. 네이티브 빌드를
  /// 쓰던 기기(대표님 기기가 그렇다)에는 델리게이트가 `SwiftUI.AppSceneDelegate`로
  /// 박제된 세션이 남아 있고, 그것이 Flutter 프로세스에서 부활하면 SwiftUI는 자기
  /// `Scene` 목록에서 해당 항목을 찾지 못해 `Missing scene item!`으로 죽는다.
  /// 실행 직후가 아니라 **첫 활성 상태 전환**에 죽는 이유는, UIKit이 그때
  /// `_saveSceneRestorationState`에서 델리게이트에게 복원 액티비티를 묻기 때문이다.
  ///
  /// 막을 방법이 이것뿐이다 — 실측으로 확인한 것:
  /// * Info.plist의 `UISceneDelegateClassName`은 **새 세션에만** 쓰인다.
  ///   부활한 세션은 박제된 클래스를 그대로 쓴다.
  /// * `application(_:configurationForConnecting:options:)`는 **호출조차 되지 않는다**
  ///   — UIKit은 부활한 세션의 구성을 앱에 묻지 않는다.
  /// * `requestSceneSessionDestruction(_:)`은 iPhone에서 거부된다
  ///   (`Invalid attempt to call ... from an unsupported device`).
  ///
  /// 그래서 씬이 붙은 직후 델리게이트를 우리 것으로 갈아끼우고, 부활한 세션에는
  /// 스토리보드 구성이 없으므로 창도 직접 만들어 붙인다. 정상 경로(우리
  /// `SceneDelegate`가 붙은 세션)에서는 아무 일도 하지 않는다.
  private func adoptSceneIfForeign(_ scene: UIWindowScene) {
    guard !(scene.delegate is SceneDelegate) else { return }

    let foreignDelegate = scene.delegate.map { String(describing: type(of: $0)) } ?? "nil"
    NSLog("[BRU-178] 이 앱의 것이 아닌 씬 델리게이트(\(foreignDelegate))를 교체합니다.")

    let adopted = SceneDelegate()
    adoptedSceneDelegates.append(adopted)
    scene.delegate = adopted

    let window = UIWindow(windowScene: scene)
    window.rootViewController = UIStoryboard(name: "Main", bundle: Bundle.main)
      .instantiateInitialViewController()
    adopted.window = window
    window.makeKeyAndVisible()
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // 네이티브 셸 채널 (BRU-160) — App Group 경로·위젯 리로드만 넘긴다.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DropNativeShell") {
      NativeShellChannel.register(with: registrar.messenger())
    }
  }
}
