package com.intellieffect.drop.core

import io.ktor.client.HttpClient
import io.ktor.client.HttpClientConfig
import io.ktor.client.engine.HttpClientEngine
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsText
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonPrimitive

/**
 * Supabase REST를 부르는 클라이언트를 만든다.
 *
 * 엔진을 인자로 받는다 — 테스트는 `MockEngine`을, 앱은 OkHttp를 넘긴다.
 * 그래서 이 모듈의 네트워크 코드가 실제 소켓 없이 검증된다.
 */
fun supabaseHttpClient(
    engine: HttpClientEngine,
    configure: HttpClientConfig<*>.() -> Unit = {},
): HttpClient = HttpClient(engine) {
    // 4xx·5xx를 예외로 바꾸지 않는다 — 본문에 든 Supabase 오류 문구를 읽어서
    // 화면에 그대로 보여 주려면 응답을 손에 쥐고 있어야 한다.
    expectSuccess = false
    install(ContentNegotiation) { json(dropJson) }
    configure()
}

/** Supabase 오류 본문에서 사람이 읽을 문구를 뽑는다. 모양이 여러 가지다. */
suspend fun HttpResponse.supabaseErrorMessage(): String {
    val body = runCatching { bodyAsText() }.getOrNull().orEmpty()
    val fromJson = runCatching {
        val obj = Json.parseToJsonElement(body) as? JsonObject ?: return@runCatching null
        ERROR_KEYS.firstNotNullOfOrNull { key ->
            obj[key]?.jsonPrimitive?.contentOrNullSafe()?.takeIf { it.isNotBlank() }
        }
    }.getOrNull()

    return fromJson ?: body.take(200).ifBlank { "HTTP ${status.value}" }
}

private val ERROR_KEYS = listOf("error_description", "msg", "message", "error", "hint", "details")

private fun kotlinx.serialization.json.JsonPrimitive.contentOrNullSafe(): String? =
    if (this is kotlinx.serialization.json.JsonNull) null else content
