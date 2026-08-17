package com.intellieffect.drop.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

/** iOS `DropConfigurationTests`의 이식본. */
class DropConfigurationTest {
    private fun values(
        url: String? = "https://example.supabase.co",
        anonKey: String? = "anon",
        webClientId: String? = "web.apps.googleusercontent.com",
    ) = mapOf(
        "SUPABASE_URL" to url,
        "SUPABASE_ANON_KEY" to anonKey,
        "GOOGLE_WEB_CLIENT_ID" to webClientId,
    )

    @Test
    fun `값이 갖춰지면 그대로 읽는다`() {
        val config = DropConfiguration.from(values())

        assertEquals("https://example.supabase.co", config.supabaseUrl)
        assertEquals("anon", config.supabaseAnonKey)
        assertEquals("web.apps.googleusercontent.com", config.googleWebClientId)
    }

    /** 경로를 이어 붙일 때 `//`가 되지 않도록 끝 슬래시를 떼어 둔다. */
    @Test
    fun `URL 끝 슬래시를 떼어낸다`() {
        assertEquals(
            "http://10.0.2.2:58321",
            DropConfiguration.from(values(url = "http://10.0.2.2:58321/")).supabaseUrl,
        )
    }

    @Test
    fun `빈 값은 어느 키든 거부한다`() {
        assertEquals(
            "SUPABASE_ANON_KEY",
            assertFailsWith<DropConfigurationException.MissingValue> {
                DropConfiguration.from(values(anonKey = "   "))
            }.key,
        )
        assertEquals(
            "GOOGLE_WEB_CLIENT_ID",
            assertFailsWith<DropConfigurationException.MissingValue> {
                DropConfiguration.from(values(webClientId = null))
            }.key,
        )
    }

    /**
     * 스킴이 잘린 값이 들어오는 사고가 잦다. 그대로 두면 첫 네트워크 호출에서야
     * 알게 되므로 구성 단계에서 끊는다.
     */
    @Test
    fun `스킴 없는 URL은 거부한다`() {
        assertFailsWith<DropConfigurationException.MalformedUrl> {
            DropConfiguration.from(values(url = "example.supabase.co"))
        }
    }
}
