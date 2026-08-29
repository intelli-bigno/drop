package com.intellieffect.drop.mobile.widget

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.widget.RemoteViews
import com.intellieffect.drop.mobile.R

/**
 * 아이콘 하나와 행선지 하나뿐인 위젯들 — 새 노트·카메라·갤러리 (BRU-189).
 * iOS `DropWidget.swift`의 `QuickComposeWidget`·`CameraWidget`·`GalleryWidget` 대응.
 *
 * 세 벌로 베껴 두면 한쪽만 고쳐지는 자리가 생기므로 여는 링크·아이콘·문구만 다르게 준다.
 */
abstract class ShortcutWidgetProvider : AppWidgetProvider() {
    protected abstract val link: Uri
    protected abstract val iconResource: Int
    protected abstract val labelResource: Int

    /** PendingIntent가 서로를 덮어쓰지 않도록 위젯마다 다른 값. */
    protected abstract val requestCode: Int

    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        val views = RemoteViews(context.packageName, R.layout.widget_shortcut).apply {
            setImageViewResource(R.id.widget_shortcut_icon, iconResource)
            setTextViewText(R.id.widget_shortcut_label, context.getString(labelResource))
            setContentDescription(R.id.widget_shortcut_icon, context.getString(labelResource))
            setOnClickPendingIntent(android.R.id.background, openAppIntent(context, link, requestCode))
        }
        for (id in appWidgetIds) {
            manager.updateAppWidget(id, views)
        }
    }
}

class QuickComposeWidgetProvider : ShortcutWidgetProvider() {
    override val link = DropLinks.quickCompose
    override val iconResource = R.drawable.ic_widget_compose
    override val labelResource = R.string.widget_compose_title
    override val requestCode = 1_891
}

class CameraWidgetProvider : ShortcutWidgetProvider() {
    override val link = DropLinks.camera
    override val iconResource = R.drawable.ic_widget_camera
    override val labelResource = R.string.widget_camera_title
    override val requestCode = 1_892
}

class GalleryWidgetProvider : ShortcutWidgetProvider() {
    override val link = DropLinks.gallery
    override val iconResource = R.drawable.ic_widget_gallery
    override val labelResource = R.string.widget_gallery_title
    override val requestCode = 1_893
}
