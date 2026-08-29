package com.intellieffect.drop.mobile.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter(`lib/native/native_shell.dart`)와의 통로 — iOS `Runner/NativeShellChannel.swift`의 짝.
 *
 * 하는 일은 둘뿐이다: 앱과 위젯이 함께 보는 디렉토리 경로를 알려 주는 것과, 위젯을
 * 다시 그리게 하는 것. 스냅샷을 만드는 규칙은 전부 drop_core(순수 Dart)에 있다.
 *
 * 메서드 이름(`appGroupContainerPath`)은 iOS에서 온 것이라 Android에는 App Group이
 * 없지만 그대로 둔다 — 이름을 바꾸면 Dart와 iOS를 함께 고쳐야 하고, 얻는 것은 없다.
 */
object NativeShellChannel {
    private const val CHANNEL = "drop/native_shell"

    fun register(context: Context, messenger: BinaryMessenger) {
        val applicationContext = context.applicationContext
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "appGroupContainerPath" -> result.success(
                    DropShellContainer.directory(applicationContext).absolutePath,
                )

                "reloadWidgets" -> {
                    reloadWidgets(applicationContext)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    /**
     * iOS `WidgetCenter.reloadAllTimelines` 대응. 홈 화면에 실제로 올라와 있는 위젯만
     * 다시 그린다.
     *
     * `ACTION_APPWIDGET_UPDATE`를 스스로 브로드캐스트하는 흔한 방식을 쓰지 않는다 —
     * 그 액션은 보호된 브로드캐스트라 시스템만 보낼 수 있다(에뮬레이터 실측:
     * `SecurityException: Permission Denial: not allowed to send broadcast
     * android.appwidget.action.APPWIDGET_UPDATE`). 프로바이더의 `onUpdate`를 직접
     * 부르면 시스템이 부를 때와 같은 경로를 타면서 그 함정을 비켜간다.
     */
    fun reloadWidgets(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        for (provider in DropWidgetProviders.all) {
            val ids = manager.getAppWidgetIds(ComponentName(context, provider.javaClass))
            if (ids.isEmpty()) continue
            provider.onUpdate(context, manager, ids)
        }
    }
}

/** 한 곳에서 센다 — 위젯을 늘릴 때 갱신 대상에서 빠지는 자리를 만들지 않기 위해. */
object DropWidgetProviders {
    val all: List<AppWidgetProvider>
        get() = listOf(
            RecentNotesWidgetProvider(),
            QuickComposeWidgetProvider(),
            CameraWidgetProvider(),
            GalleryWidgetProvider(),
        )
}
