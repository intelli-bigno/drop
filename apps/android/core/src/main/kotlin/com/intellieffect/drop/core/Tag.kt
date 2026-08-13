package com.intellieffect.drop.core

import java.time.Instant

data class Tag(
    val id: String,
    val name: String,
    val createdAt: Instant,
)
