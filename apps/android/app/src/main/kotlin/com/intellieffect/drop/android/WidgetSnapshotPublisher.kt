package com.intellieffect.drop.android

import android.content.Context
import androidx.glance.appwidget.updateAll
import com.intellieffect.drop.core.Note
import com.intellieffect.drop.core.WidgetSnapshot

/**
 * 앱이 목록을 불러올 때마다 위젯용 스냅샷을 적고 위젯을 다시 그리게 한다
 * (iOS `WidgetSnapshotPublisher`와 같은 자리).
 *
 * 위젯이 Supabase를 직접 보지 않는 이유가 여기 있다 — 위젯이 그려지는 순간에는 세션이
 * 만료돼 있을 수도, 앱 프로세스가 죽어 있을 수도 있다. 앱이 살아 있을 때 미리 적어 둔다.
 */
class WidgetSnapshotPublisher(private val context: Context) {
    private val store = widgetSnapshotStore(context)

    /** 목록이 바뀔 때마다 부른다. 실패해도 앱 흐름을 막지 않는다 — 위젯만 옛것을 보여 준다. */
    suspend fun publish(notes: List<Note>) {
        runCatching {
            store.write(WidgetSnapshot.from(notes))
            DropWidget().updateAll(context)
        }
    }

    /** 로그아웃 시 남은 노트가 위젯에 계속 보이면 안 된다. */
    suspend fun clear() {
        runCatching {
            store.write(WidgetSnapshot.EMPTY)
            DropWidget().updateAll(context)
        }
    }
}
