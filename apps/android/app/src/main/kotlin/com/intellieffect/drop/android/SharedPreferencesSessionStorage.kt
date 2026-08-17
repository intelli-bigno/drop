package com.intellieffect.drop.android

import android.content.Context
import com.intellieffect.drop.core.DropUser
import com.intellieffect.drop.core.Session
import java.time.Instant

/**
 * 세션을 앱 재시작 후에도 남긴다.
 *
 * 앱 전용 SharedPreferences는 루팅되지 않은 기기에서 다른 앱이 읽을 수 없다.
 * `EncryptedSharedPreferences`(androidx.security)는 2025년에 폐기 예정으로 표시됐고,
 * 얻는 것(기기 잠금 해제 상태에서의 추가 방어)에 비해 의존이 무거워 쓰지 않는다.
 */
class SharedPreferencesSessionStorage(context: Context) :
    com.intellieffect.drop.core.SessionStorage {
    private val preferences = context.applicationContext
        .getSharedPreferences("drop.session", Context.MODE_PRIVATE)

    override fun load(): Session? {
        val accessToken = preferences.getString(KEY_ACCESS, null) ?: return null
        val refreshToken = preferences.getString(KEY_REFRESH, null) ?: return null
        val userId = preferences.getString(KEY_USER_ID, null) ?: return null
        val expiresAt = preferences.getLong(KEY_EXPIRES_AT, 0).takeIf { it > 0 } ?: return null

        return Session(
            accessToken = accessToken,
            refreshToken = refreshToken,
            expiresAt = Instant.ofEpochSecond(expiresAt),
            user = DropUser(id = userId, email = preferences.getString(KEY_EMAIL, null)),
        )
    }

    override fun save(session: Session) {
        preferences.edit()
            .putString(KEY_ACCESS, session.accessToken)
            .putString(KEY_REFRESH, session.refreshToken)
            .putLong(KEY_EXPIRES_AT, session.expiresAt.epochSecond)
            .putString(KEY_USER_ID, session.user.id)
            .putString(KEY_EMAIL, session.user.email)
            .apply()
    }

    override fun clear() {
        preferences.edit().clear().apply()
    }

    private companion object {
        const val KEY_ACCESS = "access_token"
        const val KEY_REFRESH = "refresh_token"
        const val KEY_EXPIRES_AT = "expires_at"
        const val KEY_USER_ID = "user_id"
        const val KEY_EMAIL = "email"
    }
}
