package com.intellieffect.drop.android

import android.app.Activity
import android.app.Application
import androidx.lifecycle.AndroidViewModel
import com.intellieffect.drop.core.AuthStore
import com.intellieffect.drop.core.GoogleIdentity
import com.intellieffect.drop.core.GoogleIdentityProvider
import com.intellieffect.drop.core.NotesStore

/**
 * 화면 회전을 넘어 사는 상태. 여기 있어야 하는 이유:
 * Activity마다 새로 만들면 회전할 때 목록이 다시 불려 오고 로그인 화면이 깜빡인다.
 */
class DropViewModel(application: Application) : AndroidViewModel(application) {
    private val container = (application as DropApplication).container

    /**
     * 계정 선택 창은 Activity가 있어야 띄울 수 있는데, ViewModel은 Activity를 들고
     * 있으면 안 된다(누수). 그래서 창을 띄우는 순간에만 현재 Activity를 빌린다.
     */
    private val identityProvider = object : GoogleIdentityProvider {
        var host: Activity? = null

        override suspend fun signIn(): GoogleIdentity? {
            val activity = host ?: return null
            return CredentialManagerIdentityProvider(
                activityContext = activity,
                serverClientId = container.configuration.googleWebClientId,
            ).signIn()
        }

        override fun signOut() = Unit
    }

    val authStore = AuthStore(gateway = container.authGateway, identityProvider = identityProvider)
    val notesStore = NotesStore(container.notesRepository)

    fun attach(activity: Activity) {
        identityProvider.host = activity
    }

    fun detach() {
        identityProvider.host = null
    }
}
