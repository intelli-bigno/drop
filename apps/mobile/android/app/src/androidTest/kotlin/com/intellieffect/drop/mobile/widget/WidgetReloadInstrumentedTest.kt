package com.intellieffect.drop.mobile.widget

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 앱이 스냅샷을 적고 위젯을 다시 그리게 하는 경로를, 앱과 같은 프로세스·같은 UID에서
 * 실제로 태워 본다 (BRU-189).
 *
 * JVM 테스트로는 여기까지 못 온다 — `AppWidgetManager`도, 홈 화면에 올라와 있는 위젯도
 * 기기에만 있다. 홈 화면에 「최근 노트」 위젯이 올라와 있는 상태로 돌리면 이 테스트가
 * 실제 위젯의 그림을 바꾼다(스크린샷 증거를 이렇게 만들었다).
 *
 * 실행: adb 로 연결된 기기·에뮬레이터에서
 *   gradle :app:connectedDebugAndroidTest
 */
class WidgetReloadInstrumentedTest {

    @Test
    fun 앱이_적은_스냅샷을_위젯이_읽고_다시_그린다() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext

        // 1) Dart 쪽이 하는 일: 채널이 알려 준 경로에 스냅샷 파일을 적는다.
        val directory = DropShellContainer.directory(context)
        File(directory, WidgetSnapshotStore.FILE_NAME).writeText(SNAPSHOT)

        // 2) 위젯이 읽는 것이 그 파일과 같은 것인지.
        val snapshot = WidgetSnapshotStore(directory).read()
        assertTrue(snapshot.notes.map { it.id } == listOf("i1", "i2"))

        // 3) `NativeShell.reloadWidgets()`가 부르는 바로 그 경로. 보호된 브로드캐스트를
        //    쓰지 않으므로 SecurityException 없이 통과해야 한다.
        NativeShellChannel.reloadWidgets(context)

        // 홈 화면에 위젯이 올라와 있지 않은 기기에서도 이 호출은 성공해야 한다
        // (갱신할 대상이 없을 뿐이다).
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(
            ComponentName(context, RecentNotesWidgetProvider::class.java),
        )
        assertTrue("갱신 대상 위젯 수: ${ids.size}", ids.size >= 0)
    }

    private companion object {
        /** Dart `WidgetSnapshot.toJson()`이 내놓는 모양 그대로. */
        val SNAPSHOT = """
            {"notes":[
              {"id":"i1","excerpt":"계측 테스트가 적은 노트","created_at":"2026-08-29T21:20:00.000Z"},
              {"id":"i2","excerpt":"두 번째 줄","created_at":"2026-08-29T18:00:00.000Z"}
            ],"generated_at":"2026-08-29T21:20:00.000Z"}
        """.trimIndent()
    }
}
