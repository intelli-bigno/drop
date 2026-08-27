package com.intellieffect.drop.android

import android.content.Context

/**
 * 디버그 빌드의 조립. 릴리스(`src/release`)와 같은 이름·같은 계약이고,
 * 다른 점은 여기에만 프리뷰(인메모리) 조립이 붙을 수 있다는 것이다.
 */
object DropContainerFactory {
    fun create(context: Context): DropContainer = DropContainer.supabase(context)
}
