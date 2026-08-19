package com.intellieffect.drop.android

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.compositeOver

/**
 * 앱 전역 테마 (BRU-76). 웜 페이퍼 팔레트를 M3 색 역할에 물린다.
 *
 * **다이내믹 컬러(Material You)는 쓰지 않는다.** 배선 자체를 하지 않았다 —
 * 플래그로 남겨 두면 언젠가 켜지고, 그 순간 기기 배경화면에 따라 색이 바뀌어
 * 데스크톱·iOS·Android "세 앱 통일"이 Android에서만 무너진다. 브랜드 색이 있는
 * 앱의 정석 선택이다.
 *
 * **유리 흉내를 내지 않는다.** iOS의 Liquid Glass(BRU-75)와 재질이 다른 것은
 * 의도된 것이고, 같아야 하는 것은 색·간격·타이포다. M3의 표면·고도 체계를 그대로 쓴다.
 *
 * 색값은 전부 [DropTokens]에서 온다 — 정본은 `design-system/drop/tokens.json`이고
 * `DropTokens.kt`는 생성물이라 손대지 않는다. 여기가 하는 일은 "토큰 → M3 역할"
 * 매핑 하나뿐이다.
 */
@Composable
fun DropTheme(
    isDark: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (isDark) DropColorSchemes.dark else DropColorSchemes.light,
        content = content,
    )
}

/**
 * 라이트·다크 두 벌. 위젯(`GlanceTheme`)도 **같은 이 두 벌**을 쓴다 —
 * 위젯은 앱과 별도 프로세스에서 그려지므로, 따로 만들면 홈 화면에만 옛 색이 남는다.
 */
object DropColorSchemes {
    val light: ColorScheme = with(DropTokens.Light) {
        lightColorScheme(
            // 강조색은 주황 하나다. 그 위의 글자는 흰색이 아니라 어두운 색이어야
            // 대비가 선다 (흰 글자는 4.5:1을 넘기지 못한다) — 토큰이 그렇게 정해 두었다.
            primary = accent,
            onPrimary = textOnAccent,
            // 강조색 12% 를 종이 위에 얹은 색. 토큰의 반투명 값을 그대로 쓰면
            // 그 위에 그려지는 것들이 배경을 비쳐 층이 어긋난다.
            primaryContainer = accentSubtle.compositeOver(bgPrimary),
            onPrimaryContainer = textPrimary,
            inversePrimary = DropTokens.Dark.accent,

            secondary = cta,
            onSecondary = bgCard,
            // 선택된 목록 행의 배경. 종이보다 한 단 진한 정도여야 선택이 보이면서
            // 본문을 가리지 않는다.
            secondaryContainer = bgTertiary,
            onSecondaryContainer = textPrimary,

            tertiary = accentHover,
            onTertiary = bgCard,
            // 스와이프(고정·보관 해제·되살리기) 배경. 파괴적이지 않은 동작이라
            // 경고색이 아니라 강조색 계열로 둔다.
            tertiaryContainer = accentSubtle.compositeOver(bgPrimary),
            onTertiaryContainer = accentHover,

            error = danger,
            onError = bgCard,
            // 스와이프(보관·휴지통·영구 삭제) 배경. 토큰에 옅은 빨강이 없어
            // 경고색을 종이 위에 얇게 얹어 만든다 — 새 리터럴을 만들지 않기 위해서다.
            errorContainer = danger.copy(alpha = CONTAINER_ALPHA_LIGHT).compositeOver(bgPrimary),
            onErrorContainer = dangerHover,

            background = bgPrimary,
            onBackground = textPrimary,
            surface = bgCard,
            onSurface = textPrimary,
            surfaceVariant = bgSecondary,
            onSurfaceVariant = textSecondary,
            surfaceTint = accent,
            inverseSurface = DropTokens.Dark.bgCard,
            inverseOnSurface = DropTokens.Dark.textPrimary,

            // M3의 표면 층. 시트·상단바·카드가 이 층들을 골라 쓴다.
            surfaceContainerLowest = bgCard,
            surfaceContainerLow = bgPrimary,
            surfaceContainer = bgSecondary,
            surfaceContainerHigh = bgTertiary,
            surfaceContainerHighest = bgHover,

            outline = textTertiary,
            // 목록 구분선. 반투명 테두리를 종이 위에 얹은 실제 색으로 쓴다.
            outlineVariant = borderColor.compositeOver(bgPrimary),
            scrim = Color.Black,
        )
    }

    val dark: ColorScheme = with(DropTokens.Dark) {
        darkColorScheme(
            primary = accent,
            onPrimary = textOnAccent,
            primaryContainer = accentSubtle.compositeOver(bgPrimary),
            onPrimaryContainer = textPrimary,
            inversePrimary = DropTokens.Light.accent,

            secondary = cta,
            onSecondary = textOnAccent,
            secondaryContainer = bgTertiary,
            onSecondaryContainer = textPrimary,

            tertiary = accentHover,
            onTertiary = textOnAccent,
            tertiaryContainer = accentSubtle.compositeOver(bgPrimary),
            onTertiaryContainer = accent,

            error = danger,
            onError = textOnAccent,
            errorContainer = danger.copy(alpha = CONTAINER_ALPHA_DARK).compositeOver(bgPrimary),
            onErrorContainer = dangerHover,

            // background(#191919)와 surface(#202020)를 **다르게** 둔다.
            // 같은 값이면 다크에서 카드·행의 경계가 사라진다.
            background = bgPrimary,
            onBackground = textPrimary,
            surface = bgCard,
            onSurface = textPrimary,
            surfaceVariant = bgTertiary,
            onSurfaceVariant = textSecondary,
            surfaceTint = accent,
            inverseSurface = DropTokens.Light.bgCard,
            inverseOnSurface = DropTokens.Light.textPrimary,

            surfaceContainerLowest = bgPrimary,
            surfaceContainerLow = bgSecondary,
            surfaceContainer = bgCard,
            surfaceContainerHigh = bgElevated,
            surfaceContainerHighest = bgTertiary,

            outline = textTertiary,
            outlineVariant = borderColor.compositeOver(bgCard),
            scrim = Color.Black,
        )
    }

    /**
     * 옅은 경고 배경을 만들 때 얹는 두께. 다크에서 더 두껍게 얹는다 —
     * 어두운 바탕에서는 같은 알파가 훨씬 덜 보인다 (토큰의 accentSubtle도
     * 라이트 0x1F · 다크 0x24로 같은 조정을 한다).
     */
    private const val CONTAINER_ALPHA_LIGHT = 0.12f
    private const val CONTAINER_ALPHA_DARK = 0.24f
}
