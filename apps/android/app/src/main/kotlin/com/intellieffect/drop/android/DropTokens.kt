// 이 파일은 생성물이다 — 직접 고치지 마라.
// 정본: design-system/drop/tokens.json
// 재생성: make tokens

package com.intellieffect.drop.android

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * 생성된 색·치수 토큰. 화면은 이 값만 쓴다 — 리터럴 색을 Composable에 적으면
 * 세 앱의 색이 다시 갈라진다.
 */
object DropTokens {
    object Light {
        val bgPrimary = Color(0xFFF7F6F3)
        val bgSecondary = Color(0xFFF1EFEA)
        val bgCard = Color(0xFFFFFFFF)
        val bgElevated = Color(0xFFFFFFFF)
        val bgTertiary = Color(0xFFEDEAE3)
        val bgHover = Color(0xFFEDEAE3)
        val accent = Color(0xFFD9730D)
        val accentHover = Color(0xFFB45309)
        val accentSubtle = Color(0x1FD9730D)
        val cta = Color(0xFFD0460D)
        val ctaHover = Color(0xFF9A3412)
        val textOnAccent = Color(0xFF000000)
        val textPrimary = Color(0xFF37352F)
        val textSecondary = Color(0xFF6B6862)
        val textTertiary = Color(0xFF8D8C89)
        val textMuted = Color(0xFFB4B2AC)
        val borderColor = Color(0x1F37352F)
        val borderSubtle = Color(0x0F37352F)
        val borderFocus = Color(0xFFD9730D)
        val priorityLow = Color(0xFF6B7280)
        val priorityMedium = Color(0xFFF59E0B)
        val priorityHigh = Color(0xFFEF4444)
        val success = Color(0xFF22C55E)
        val warning = Color(0xFFF59E0B)
        val danger = Color(0xFFDA2323)
        val dangerHover = Color(0xFFB91C1C)
        val dangerSubtle = Color(0x1ADA2323)
        val overlay = Color(0x5237352F)
        val overlayStrong = Color(0xEB000000)
        val overlayControl = Color(0x1FFFFFFF)
        val overlayControlHover = Color(0x38FFFFFF)
        val overlayScrim = Color(0x8C000000)
        val textOnOverlay = Color(0xFFFFFFFF)
        val textOnDanger = Color(0xFFFFFFFF)
        val brandInstagram = Color(0xFFE1306C)
        val brandYoutube = Color(0xFFFF0000)
    }

    object Dark {
        val bgPrimary = Color(0xFF191919)
        val bgSecondary = Color(0xFF1C1C1C)
        val bgCard = Color(0xFF202020)
        val bgElevated = Color(0xFF262626)
        val bgTertiary = Color(0xFF2A2A2A)
        val bgHover = Color(0xFF2E2E2E)
        val accent = Color(0xFFE9A23B)
        val accentHover = Color(0xFFF2B45A)
        val accentSubtle = Color(0x24E9A23B)
        val cta = Color(0xFFF97316)
        val ctaHover = Color(0xFFFB923C)
        val textOnAccent = Color(0xFF000000)
        val textPrimary = Color(0xFFD4D4D4)
        val textSecondary = Color(0xFFA8A6A1)
        val textTertiary = Color(0xFF8C8C8C)
        val textMuted = Color(0xFF6B6A66)
        val borderColor = Color(0x17FFFFFF)
        val borderSubtle = Color(0x0DFFFFFF)
        val borderFocus = Color(0xFFE9A23B)
        val priorityLow = Color(0xFF6B7280)
        val priorityMedium = Color(0xFFF59E0B)
        val priorityHigh = Color(0xFFEF4444)
        val success = Color(0xFF22C55E)
        val warning = Color(0xFFF59E0B)
        val danger = Color(0xFFEF4444)
        val dangerHover = Color(0xFFF87171)
        val dangerSubtle = Color(0x24EF4444)
        val overlay = Color(0x99000000)
        val overlayStrong = Color(0xEB000000)
        val overlayControl = Color(0x1FFFFFFF)
        val overlayControlHover = Color(0x38FFFFFF)
        val overlayScrim = Color(0x8C000000)
        val textOnOverlay = Color(0xFFFFFFFF)
        val textOnDanger = Color(0xFFFFFFFF)
        val brandInstagram = Color(0xFFE1306C)
        val brandYoutube = Color(0xFFFF0000)
    }

    object Space {
        val x1 = 4.dp
        val x2 = 8.dp
        val x3 = 12.dp
        val x4 = 16.dp
        val x5 = 24.dp
        val x6 = 32.dp
        val x7 = 48.dp
        val x8 = 64.dp
    }

    object Radius {
        val sm = 6.dp
        val md = 8.dp
        val lg = 12.dp
        val xl = 16.dp
    }

    object TextSize {
        val xs = 11.sp
        val sm = 12.sp
        val base = 14.sp
        val lg = 16.sp
        val xl = 20.sp
        val _2xl = 28.sp
        val _3xl = 44.sp
    }
}
