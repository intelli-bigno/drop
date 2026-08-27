package com.intellieffect.drop.android

import android.content.Context

/**
 * 디버그 빌드의 조립. 릴리스(`src/release`)와 같은 이름·같은 계약이고,
 * 다른 점은 여기에만 프리뷰(인메모리) 조립이 붙어 있다는 것이다.
 *
 * `-PdropPreview=true`(= `make android-preview`)로 빌드하면 [PreviewLaunch]가
 * 자격증명 없이 화면·위젯을 띄운다. 그 외에는 릴리스와 똑같이 Supabase에 붙는다.
 */
object DropContainerFactory {
    fun create(context: Context): DropContainer =
        if (BuildConfig.DROP_PREVIEW) PreviewLaunch.makeContainer(context) else DropContainer.supabase(context)
}
