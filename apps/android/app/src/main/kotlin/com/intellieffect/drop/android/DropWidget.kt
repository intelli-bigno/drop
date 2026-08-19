package com.intellieffect.drop.android

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.color.ColorProviders as GlanceColorScheme
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.material3.ColorProviders
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import com.intellieffect.drop.core.RelativeTimeFormatter
import com.intellieffect.drop.core.WidgetSnapshot
import com.intellieffect.drop.core.WidgetSnapshotStore
import java.io.File

/**
 * 홈 화면 위젯 (iOS `DropWidget`과 같은 사양 — 최근 노트 세 줄 + 빠른 작성).
 *
 * **네트워크도 세션도 보지 않는다.** 앱이 노트를 불러올 때마다 적어 둔 스냅샷 파일만 읽는다
 * ([WidgetSnapshotPublisher]). 위젯은 앱 프로세스가 죽어 있을 때도 그려져야 하고,
 * 그 순간에는 세션 갱신도 네트워크도 기대할 수 없다.
 */
class DropWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        // 읽기는 실패하지 않는다 — 파일이 없거나 깨졌으면 빈 스냅샷이 온다.
        val snapshot = widgetSnapshotStore(context).read()

        provideContent {
            // 앱과 **같은** 두 벌을 넘긴다. 인자 없이 GlanceTheme를 쓰면 Material 기본
            // 팔레트(또는 기기의 다이내믹 컬러)로 그려져 홈 화면에만 옛 색이 남는다 —
            // 위젯은 앱과 별도 프로세스에서 그려지므로 앱 테마가 여기까지 오지 않는다.
            GlanceTheme(colors = DropGlanceColors) {
                WidgetBody(snapshot)
            }
        }
    }
}

@Composable
private fun WidgetBody(snapshot: WidgetSnapshot) {
    val formatter = RelativeTimeFormatter()

    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(GlanceTheme.colors.background)
            .padding(12.dp)
            .clickable(actionStartActivity<MainActivity>()),
    ) {
        Row(modifier = GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = "DROP",
                style = TextStyle(color = GlanceTheme.colors.onSurface, fontSize = 14.sp),
            )
            Spacer(GlanceModifier.defaultWeight())
            // ＋ 는 작성 시트를 열고 시작한다 — 위젯의 값은 탭 한 번으로 담기 시작하는 것이다.
            Text(
                text = "＋",
                style = TextStyle(color = GlanceTheme.colors.primary, fontSize = 20.sp),
                // Glance는 ActionParameters를 Activity 인텐트 extra로 넘긴다 —
                // MainActivity가 같은 키로 읽는다.
                modifier = GlanceModifier.clickable(
                    actionStartActivity<MainActivity>(
                        actionParametersOf(startComposerKey to true),
                    ),
                ),
            )
        }

        Spacer(GlanceModifier.height(8.dp))

        if (snapshot.isEmpty) {
            Text(
                text = "아직 노트가 없습니다",
                style = TextStyle(color = GlanceTheme.colors.onSurfaceVariant, fontSize = 12.sp),
            )
        } else {
            snapshot.notes.forEach { note ->
                Column(modifier = GlanceModifier.padding(bottom = 6.dp)) {
                    Text(
                        text = note.excerpt,
                        maxLines = 2,
                        style = TextStyle(color = GlanceTheme.colors.onSurface, fontSize = 13.sp),
                    )
                    Text(
                        text = formatter.format(note.createdAt),
                        style = TextStyle(color = GlanceTheme.colors.onSurfaceVariant, fontSize = 10.sp),
                    )
                }
            }
        }
    }
}

/** 시스템이 위젯을 그릴 때 부르는 진입점. 이 receiver가 없으면 위젯 갤러리에 뜨지 않는다. */
class DropWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = DropWidget()
}

/**
 * 위젯이 쓰는 색. 앱의 [DropColorSchemes]를 그대로 넘긴다 (BRU-76) —
 * 위젯만 따로 정의하면 두 곳이 언젠가 갈라진다.
 */
private val DropGlanceColors: GlanceColorScheme = ColorProviders(
    light = DropColorSchemes.light,
    dark = DropColorSchemes.dark,
)

/** 위젯의 ＋ 가 넘기는 표시. MainActivity가 같은 이름의 extra로 읽는다. */
val startComposerKey = ActionParameters.Key<Boolean>(MainActivity.EXTRA_START_COMPOSER)

/** 앱과 위젯이 같은 파일을 보게 하는 자리. */
fun widgetSnapshotStore(context: Context): WidgetSnapshotStore =
    WidgetSnapshotStore(File(context.applicationContext.filesDir, "widget-snapshot.json"))
