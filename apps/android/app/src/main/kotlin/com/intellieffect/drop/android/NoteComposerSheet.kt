package com.intellieffect.drop.android

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.unit.dp

/**
 * 노트 작성·수정 시트.
 *
 * 원문 보존: 저장할 때 본문을 다듬지 않는다. 앞뒤 공백만 보고 "비었는지"를 판단하고,
 * **저장되는 값은 사용자가 입력한 그대로**다 (데스크톱 BRU-66에서 원문이 변형된 사고가 있었다).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NoteComposerSheet(
    initialContent: String,
    onDismiss: () -> Unit,
    onSubmit: (String) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    // 커서를 본문 끝에 둔다. 기본값(0)이면 수정할 때 입력이 맨 앞에 끼어든다.
    var value by remember {
        mutableStateOf(
            TextFieldValue(initialContent, selection = TextRange(initialContent.length)),
        )
    }
    val text = value.text
    val focusRequester = remember { FocusRequester() }
    val keyboard = LocalSoftwareKeyboardController.current

    // 시트가 뜨면 바로 쓸 수 있어야 한다 — 퀵캡처 앱에서 탭 한 번이 아깝다.
    LaunchedEffect(Unit) {
        focusRequester.requestFocus()
        keyboard?.show()
    }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(16.dp).imePadding(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            OutlinedTextField(
                value = value,
                onValueChange = { value = it },
                modifier = Modifier.fillMaxWidth().focusRequester(focusRequester),
                minLines = 4,
                placeholder = { Text("떠오른 것을 담아 두세요") },
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.End),
            ) {
                TextButton(onClick = onDismiss) { Text("취소") }
                Button(
                    // 공백뿐인 노트는 만들지 않는다. 판단만 trim으로 하고 값은 원문 그대로 넘긴다.
                    enabled = text.isNotBlank() && text != initialContent,
                    onClick = { onSubmit(text) },
                ) { Text("저장") }
            }
        }
    }
}
