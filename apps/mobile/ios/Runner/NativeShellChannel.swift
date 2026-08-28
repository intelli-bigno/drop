import Flutter
import Foundation
import WidgetKit

/// Flutter(`lib/native/native_shell.dart`)와의 통로.
///
/// 하는 일은 둘뿐이다 — App Group 컨테이너 경로 조회와 위젯 리로드.
/// 공유 수신함 파싱·위젯 스냅샷 빌드는 전부 drop_core(순수 Dart)가 한다.
enum NativeShellChannel {
    /// 확장(`DropShell/DropShellCore.swift`)과 같은 그룹.
    static let appGroupID = "group.com.intellieffect.drop.shared"

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "drop/native_shell", binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "appGroupContainerPath":
                // App Group이 설정돼 있지 않으면 nil — Dart 쪽이 공유·위젯 기능만
                // 조용히 끄고 앱의 나머지는 그대로 돌아간다.
                result(
                    FileManager.default
                        .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
                        .path
                )
            case "reloadWidgets":
                WidgetCenter.shared.reloadAllTimelines()
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}
