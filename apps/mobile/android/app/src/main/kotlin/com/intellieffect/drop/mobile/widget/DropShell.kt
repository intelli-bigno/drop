package com.intellieffect.drop.mobile.widget

import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import java.io.File

/**
 * 위젯이 여는 링크. 해석은 앱(drop_core `DropLink`)이 한다 — URL 문자열이 계약이고
 * iOS `DropShellLink`와 글자까지 같아야 한다.
 */
object DropLinks {
    val quickCompose: Uri = Uri.parse("drop://compose")
    val camera: Uri = Uri.parse("drop://camera")
    val gallery: Uri = Uri.parse("drop://gallery")

    fun note(id: String): Uri = Uri.parse("drop://note/$id")
}

/**
 * 앱과 위젯이 함께 보는 자리. iOS는 App Group 컨테이너를 쓰지만 Android 위젯은
 * 앱과 같은 UID·같은 프로세스 권한으로 돌아서 앱 내부 저장소면 충분하다 —
 * App Group에 해당하는 장치가 필요 없다.
 *
 * Dart 쪽(`NativeShell.appGroupContainerPath()`)은 "경로 문자열 하나"만 알면 되므로
 * 채널 계약은 iOS와 그대로 같다.
 */
object DropShellContainer {
    private const val DIRECTORY_NAME = "drop_shell"

    fun directory(context: Context): File =
        File(context.filesDir, DIRECTORY_NAME).apply { mkdirs() }
}

/**
 * 위젯 탭 → 앱. 링크마다 requestCode를 달리 준다 — 같은 코드를 쓰면 뒤에 만든
 * PendingIntent가 앞의 것을 덮어써서 모든 줄이 같은 노트를 연다.
 */
internal fun openAppIntent(context: Context, uri: Uri, requestCode: Int): PendingIntent {
    val intent = Intent(Intent.ACTION_VIEW, uri).apply {
        component = ComponentName(context, "com.intellieffect.drop.mobile.MainActivity")
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
    }
    return PendingIntent.getActivity(
        context,
        requestCode,
        intent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}
