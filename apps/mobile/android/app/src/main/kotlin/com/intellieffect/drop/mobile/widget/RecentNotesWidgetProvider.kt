package com.intellieffect.drop.mobile.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.view.View
import android.widget.RemoteViews
import com.intellieffect.drop.mobile.R

/**
 * 최근 노트 위젯 (BRU-189). iOS `DropWidget.swift`의 `RecentNotesWidget` 대응.
 *
 * 왜 Glance(Compose)가 아니라 RemoteViews인가: 이 앱은 Flutter라 Compose가 한 줄도
 * 없다. Glance는 Compose 런타임·컴파일러 플러그인을 통째로 들여오는데, Glance 자신도
 * 결국 RemoteViews로 내려간다 — 텍스트 세 줄과 아이콘 하나를 그리자고 치를 값이 아니다.
 *
 * 보여 줄 것을 고르고 자르는 규칙은 앱(drop_core, Dart)에 있고 테스트가 덮는다.
 * 여기서는 이미 정해진 것을 배치만 한다.
 */
class RecentNotesWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        val snapshot = WidgetSnapshotStore(DropShellContainer.directory(context)).read()
        for (id in appWidgetIds) {
            manager.updateAppWidget(id, buildViews(context, snapshot))
        }
    }

    private companion object {
        /** 줄마다 다른 requestCode — 같은 값을 주면 모든 줄이 같은 노트를 연다. */
        const val REQUEST_CODE_BASE = 1_890

        val ROW_IDS = intArrayOf(R.id.widget_note_0, R.id.widget_note_1, R.id.widget_note_2)
        val EXCERPT_IDS =
            intArrayOf(R.id.widget_note_0_excerpt, R.id.widget_note_1_excerpt, R.id.widget_note_2_excerpt)
        val TIME_IDS =
            intArrayOf(R.id.widget_note_0_time, R.id.widget_note_1_time, R.id.widget_note_2_time)

        fun buildViews(context: Context, snapshot: WidgetSnapshot): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_recent_notes)
            val time = RelativeTimeFormatter()

            // 빈 상태 안내와 노트 줄은 서로를 가린다.
            val emptyVisibility = if (snapshot.isEmpty) View.VISIBLE else View.GONE
            views.setViewVisibility(R.id.widget_empty_title, emptyVisibility)
            views.setViewVisibility(R.id.widget_empty_hint, emptyVisibility)

            val notes = snapshot.notes.take(WidgetSnapshot.MAXIMUM_NOTE_COUNT)
            for (index in ROW_IDS.indices) {
                val note = notes.getOrNull(index)
                views.setViewVisibility(ROW_IDS[index], if (note == null) View.GONE else View.VISIBLE)
                if (note == null) continue

                views.setTextViewText(EXCERPT_IDS[index], note.excerpt)
                views.setTextViewText(TIME_IDS[index], time.format(note.createdAt))
                views.setOnClickPendingIntent(
                    ROW_IDS[index],
                    openAppIntent(context, DropLinks.note(note.id), REQUEST_CODE_BASE + index),
                )
            }

            // 헤더 아이콘과, 노트 줄을 벗어난 곳(빈 상태 포함)의 기본 행선지.
            val compose = openAppIntent(context, DropLinks.quickCompose, REQUEST_CODE_BASE + ROW_IDS.size)
            views.setOnClickPendingIntent(R.id.widget_compose, compose)
            views.setOnClickPendingIntent(android.R.id.background, compose)
            return views
        }
    }
}
