package com.intellieffect.drop.core

/**
 * 리포지토리 실패를 화면에 띄울 문구로 바꾼다. (iOS `RepositoryErrorMessage`와 같은 자리)
 *
 * 한 군데 모아 두는 이유: 노트·댓글은 같은 이유(인증·네트워크·거절·디코딩)로 실패하는데,
 * 문구가 갈라지면 같은 장애를 두 가지 말로 설명하게 된다.
 */
object RepositoryErrorMessage {
    fun text(error: Throwable): String = when (error) {
        is NotesRepositoryException.NotAuthenticated -> "로그인이 필요합니다."
        is NotesRepositoryException.Rejected -> "서버가 요청을 거절했습니다: ${error.reason}"
        is NotesRepositoryException.Network -> "네트워크에 연결하지 못했습니다."
        is NotesRepositoryException.Decoding -> "응답을 이해하지 못했습니다."
        else -> error.message ?: error.toString()
    }
}
