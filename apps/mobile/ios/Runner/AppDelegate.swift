import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // 네이티브 셸 채널 (BRU-160) — App Group 경로·위젯 리로드만 넘긴다.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DropNativeShell") {
      NativeShellChannel.register(with: registrar.messenger())
    }
  }
}
