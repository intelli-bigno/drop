package com.intellieffect.drop.android

import android.app.Application
import android.content.Context
import com.intellieffect.drop.core.AttachmentsRepository
import com.intellieffect.drop.core.AuthGateway
import com.intellieffect.drop.core.CommentsRepository
import com.intellieffect.drop.core.DropConfiguration
import com.intellieffect.drop.core.NotesRepository
import com.intellieffect.drop.core.SignedUrlCache
import com.intellieffect.drop.core.SupabaseAttachmentsRepository
import com.intellieffect.drop.core.SupabaseAuthGateway
import com.intellieffect.drop.core.SupabaseCommentsRepository
import com.intellieffect.drop.core.SupabaseNotesRepository
import com.intellieffect.drop.core.SupabaseTagsRepository
import com.intellieffect.drop.core.TagsRepository
import com.intellieffect.drop.core.supabaseHttpClient
import io.ktor.client.engine.okhttp.OkHttp

/**
 * 앱이 한 벌만 들고 있는 것들. iOS `DropEnvironmentContainer`와 같은 자리다.
 *
 * 화면(Activity)보다 오래 살아야 한다 — 화면 회전 때마다 세션을 다시 만들면
 * 갱신 중인 토큰이 둘로 갈라진다.
 *
 * 무엇을 채울지는 [DropContainerFactory]가 정한다 — 릴리스는 Supabase 한 가지,
 * 디버그는 프리뷰(인메모리)도 고를 수 있다. 화면 쪽은 이 타입만 알고, 뒤에 무엇이
 * 붙어 있는지 모른다.
 */
class DropContainer(
    val configuration: DropConfiguration,
    val authGateway: AuthGateway,
    val notesRepository: NotesRepository,
    val tagsRepository: TagsRepository,
    /** 댓글은 노트가 아니다 — 리포지토리도 따로 둔다 (BRU-86). */
    val commentsRepository: CommentsRepository,
    val attachmentsRepository: AttachmentsRepository,
) {
    /**
     * 서명 URL 캐시는 앱에 하나만 둔다 — 화면마다 만들면 같은 파일의 URL을
     * 화면 수만큼 발급하게 되어 캐시가 있으나 마나가 된다.
     */
    val signedUrlCache = SignedUrlCache(attachmentsRepository)

    companion object {
        /** 실제 Supabase에 붙는 조립. 릴리스 빌드가 아는 유일한 조립이다. */
        fun supabase(context: Context): DropContainer {
            val configuration = DropConfiguration.from(
                mapOf(
                    "SUPABASE_URL" to BuildConfig.SUPABASE_URL,
                    "SUPABASE_ANON_KEY" to BuildConfig.SUPABASE_ANON_KEY,
                    "GOOGLE_WEB_CLIENT_ID" to BuildConfig.GOOGLE_WEB_CLIENT_ID,
                ),
            )

            val httpClient = supabaseHttpClient(OkHttp.create())

            val authGateway = SupabaseAuthGateway(
                config = configuration,
                client = httpClient,
                storage = SharedPreferencesSessionStorage(context),
            )

            // 게이트웨이가 토큰 공급자를 겸한다 — 만료가 가까우면 알아서 갱신한다.
            return DropContainer(
                configuration = configuration,
                authGateway = authGateway,
                notesRepository = SupabaseNotesRepository(
                    config = configuration,
                    client = httpClient,
                    tokens = authGateway,
                ),
                tagsRepository = SupabaseTagsRepository(
                    config = configuration,
                    client = httpClient,
                    tokens = authGateway,
                ),
                commentsRepository = SupabaseCommentsRepository(
                    config = configuration,
                    client = httpClient,
                    tokens = authGateway,
                ),
                attachmentsRepository = SupabaseAttachmentsRepository(
                    config = configuration,
                    client = httpClient,
                    tokens = authGateway,
                ),
            )
        }
    }
}

class DropApplication : Application() {
    /**
     * 구성값이 비어 있으면 여기서 예외가 난다. 첫 네트워크 호출까지 미루는 것보다
     * 앱이 켜지는 순간 터지는 편이 원인을 찾기 쉽다 (iOS도 같은 자리에서 끊는다).
     */
    val container: DropContainer by lazy { DropContainerFactory.create(this) }
}
