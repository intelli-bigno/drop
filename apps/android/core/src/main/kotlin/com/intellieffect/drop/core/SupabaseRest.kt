package com.intellieffect.drop.core

import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.HttpRequestBuilder
import io.ktor.client.request.delete
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.patch
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.http.ContentType
import io.ktor.http.HttpStatusCode
import io.ktor.http.contentType
import io.ktor.http.isSuccess
import kotlin.coroutines.cancellation.CancellationException
import kotlinx.serialization.json.JsonObject

/**
 * PostgREST·Storage 호출의 공통부. 세 리포지토리(노트·태그·첨부)가 같은 헤더와
 * 같은 오류 좁히기 규칙을 쓰도록 한 군데로 모았다.
 *
 * 여기서만 하는 두 가지:
 * - 모든 요청에 `apikey`와 `Authorization`을 붙인다. 빠지면 RLS가 전부 막는다.
 * - **취소는 그대로 올려 보낸다.** 네트워크 장애로 둔갑하면 당겨서 새로고침에서 손을 뗀
 *   것만으로 오류창이 뜨고 보고 있던 목록이 지워진다 (iOS BRU-32).
 */
internal class SupabaseRest(
    private val config: DropConfiguration,
    private val client: HttpClient,
    private val tokens: AuthTokenProvider,
) {
    suspend inline fun <reified T> get(path: String): T =
        decode(request { get(restUrl(path)) { authorize() } })

    suspend inline fun <reified T> postReturning(path: String, body: JsonObject): T = decode(
        request {
            post(restUrl(path)) {
                authorize()
                // 이걸 빼면 삽입된 행이 응답에 오지 않는다.
                header("Prefer", "return=representation")
                contentType(ContentType.Application.Json)
                setBody(body)
            }
        },
    )

    suspend fun post(
        path: String,
        body: JsonObject,
        configure: HttpRequestBuilder.() -> Unit = {},
    ) {
        request {
            post(restUrl(path)) {
                authorize()
                contentType(ContentType.Application.Json)
                setBody(body)
                configure()
            }
        }
    }

    suspend fun patch(path: String, body: JsonObject) {
        request {
            patch(restUrl(path)) {
                authorize()
                contentType(ContentType.Application.Json)
                setBody(body)
            }
        }
    }

    suspend fun delete(path: String) {
        request { delete(restUrl(path)) { authorize() } }
    }

    /** 절대 URL을 지운다 (스토리지 오브젝트처럼 `/rest/v1` 밖에 있는 것). */
    suspend fun deleteUrl(url: String) {
        request { delete(url) { authorize() } }
    }

    fun restUrl(path: String): String = "${config.supabaseUrl}/rest/v1/$path"

    fun storageUrl(path: String): String = "${config.supabaseUrl}/storage/v1/$path"

    suspend fun HttpRequestBuilder.authorize() {
        val token = tokens.accessToken() ?: throw NotesRepositoryException.NotAuthenticated
        header("apikey", config.supabaseAnonKey)
        header("Authorization", "Bearer $token")
    }

    suspend fun request(operation: suspend HttpClient.() -> HttpResponse): HttpResponse {
        val response = try {
            client.operation()
        } catch (cancellation: CancellationException) {
            throw cancellation
        } catch (error: NotesRepositoryException) {
            throw error
        } catch (error: Throwable) {
            throw NotesRepositoryException.Network(error.message ?: error.toString())
        }

        if (response.status.isSuccess()) return response

        val message = response.supabaseErrorMessage()
        throw when {
            // 토큰이 죽었거나 RLS가 막은 것. 화면은 "로그인이 필요합니다"로 안내한다.
            response.status == HttpStatusCode.Unauthorized -> NotesRepositoryException.NotAuthenticated
            response.status.value >= HttpStatusCode.InternalServerError.value ->
                NotesRepositoryException.Network(message)
            else -> NotesRepositoryException.Rejected(message)
        }
    }

    suspend inline fun <reified T> decode(response: HttpResponse): T = try {
        response.body()
    } catch (cancellation: CancellationException) {
        throw cancellation
    } catch (error: Throwable) {
        throw NotesRepositoryException.Decoding(error.message ?: error.toString())
    }
}
