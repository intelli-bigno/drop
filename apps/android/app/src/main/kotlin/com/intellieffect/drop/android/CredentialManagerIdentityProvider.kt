package com.intellieffect.drop.android

import android.content.Context
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.NoCredentialException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.intellieffect.drop.core.AuthException
import com.intellieffect.drop.core.GoogleIdentity
import com.intellieffect.drop.core.GoogleIdentityProvider

/**
 * Credential Manager로 Google 계정 선택 창을 띄운다 (iOS의 `GoogleSignInIdentityProvider`와 같은 자리).
 *
 * `activityContext`는 **Activity**여야 한다 — 창을 띄우는 호출이라 애플리케이션 컨텍스트로는 안 된다.
 */
class CredentialManagerIdentityProvider(
    private val activityContext: Context,
    private val serverClientId: String,
) : GoogleIdentityProvider {
    private val credentialManager = CredentialManager.create(activityContext)

    override suspend fun signIn(): GoogleIdentity? {
        // GetSignInWithGoogleOption은 "계정으로 로그인" 창을 띄운다.
        // serverClientId에 웹 클라이언트 ID를 넘겨야 id_token의 audience가 웹 클라이언트가 되고,
        // 그래야 Supabase가 받아 준다 — 빼먹으면 `Unacceptable audience`로 거부된다.
        val option = GetSignInWithGoogleOption.Builder(serverClientId).build()
        val request = GetCredentialRequest.Builder().addCredentialOption(option).build()

        val response = try {
            credentialManager.getCredential(activityContext, request)
        } catch (_: GetCredentialCancellationException) {
            // 사용자가 창을 닫은 것 — 오류가 아니다.
            return null
        } catch (error: NoCredentialException) {
            throw AuthException.Rejected("기기에 사용할 수 있는 Google 계정이 없습니다")
        } catch (error: GetCredentialException) {
            throw AuthException.Rejected(error.errorMessage?.toString() ?: error.type)
        }

        val credential = response.credential
        if (credential.type != GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
            throw AuthException.Rejected("Google 자격증명이 아닙니다: ${credential.type}")
        }

        return GoogleIdentity(
            idToken = GoogleIdTokenCredential.createFrom(credential.data).idToken,
        )
    }

    override fun signOut() {
        // Credential Manager에는 앱이 끊을 수 있는 Google 세션이 없다.
        // (Supabase 세션은 게이트웨이가 지운다.)
    }
}
