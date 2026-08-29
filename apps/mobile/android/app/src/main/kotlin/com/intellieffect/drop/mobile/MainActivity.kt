package com.intellieffect.drop.mobile

import com.intellieffect.drop.mobile.widget.NativeShellChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    /** 홈 화면 위젯과의 통로 (BRU-189). iOS `AppDelegate`가 하는 일과 같다. */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NativeShellChannel.register(this, flutterEngine.dartExecutor.binaryMessenger)
    }
}
