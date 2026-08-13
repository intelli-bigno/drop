package com.intellieffect.drop.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.intellieffect.drop.core.InMemoryNotesRepository
import com.intellieffect.drop.core.NotesStore
import com.intellieffect.drop.core.sampleNotes
import kotlinx.coroutines.launch

/**
 * 앱 모듈은 조립만 한다 — 로직은 전부 `:core`에 있다.
 *
 * BRU-38(스캐폴드)에서는 인메모리 리포지토리를 물린다. 실제 Supabase 연결과 로그인은
 * BRU-39 이후에 붙는다.
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                val viewModel: NotesViewModel = viewModel()
                NotesScreen(viewModel.store)
            }
        }
    }
}

class NotesViewModel : ViewModel() {
    val store = NotesStore(InMemoryNotesRepository(sampleNotes()))

    init {
        viewModelScope.launch { store.load() }
    }
}
