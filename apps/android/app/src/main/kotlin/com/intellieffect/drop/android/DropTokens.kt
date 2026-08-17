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
    object Dark {
        val bgPrimary = Color(0xFF09090B)
        val bgSecondary = Color(0xFF101013)
        val bgCard = Color(0xFF17171B)
        val bgElevated = Color(0xFF1E1E23)
        val bgHover = Color(0xFF26262C)
        val accent = Color(0xFF14B8A6)
        val accentHover = Color(0xFF2DD4BF)
        val accentSubtle = Color(0x1F14B8A6)
        val cta = Color(0xFFEA580C)
        val ctaHover = Color(0xFFF97316)
        val textPrimary = Color(0xFFFAFAFA)
        val textSecondary = Color(0xFFA6A6B0)
        val textTertiary = Color(0xFF79797F)
        val textMuted = Color(0xFF55555C)
        val borderColor = Color(0x14FFFFFF)
        val borderSubtle = Color(0x0AFFFFFF)
        val borderFocus = Color(0xFF14B8A6)
        val priorityLow = Color(0xFF6B7280)
        val priorityMedium = Color(0xFFF59E0B)
        val priorityHigh = Color(0xFFEF4444)
        val success = Color(0xFF22C55E)
        val warning = Color(0xFFF59E0B)
        val danger = Color(0xFFEF4444)
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
    }
}
