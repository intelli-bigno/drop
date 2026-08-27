package com.intellieffect.drop.android

import android.content.Context

/**
 * 릴리스 빌드의 조립. Supabase 한 가지뿐이다.
 *
 * 디버그 빌드는 `src/debug`의 같은 이름 파일이 대신 들어간다 — 프리뷰(인메모리)
 * 조립은 그쪽에만 있어서 릴리스 APK에는 그 코드가 실리지 않는다.
 */
object DropContainerFactory {
    fun create(context: Context): DropContainer = DropContainer.supabase(context)
}
