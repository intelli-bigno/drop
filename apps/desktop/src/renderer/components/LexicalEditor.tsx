/// <reference path="../../preload/index.d.ts" />
import { forwardRef, useImperativeHandle, useEffect, useCallback, useRef } from 'react'
import { LexicalComposer } from '@lexical/react/LexicalComposer'
import { RichTextPlugin } from '@lexical/react/LexicalRichTextPlugin'
import { ContentEditable } from '@lexical/react/LexicalContentEditable'
import { HistoryPlugin } from '@lexical/react/LexicalHistoryPlugin'
import { OnChangePlugin } from '@lexical/react/LexicalOnChangePlugin'
import { MarkdownShortcutPlugin } from '@lexical/react/LexicalMarkdownShortcutPlugin'
import { LexicalErrorBoundary } from '@lexical/react/LexicalErrorBoundary'
import { useLexicalComposerContext } from '@lexical/react/LexicalComposerContext'
import { AutoLinkPlugin } from '@lexical/react/LexicalAutoLinkPlugin'
import { LinkPlugin } from '@lexical/react/LexicalLinkPlugin'
import { HeadingNode, QuoteNode } from '@lexical/rich-text'
import { ListNode, ListItemNode } from '@lexical/list'
import { CodeNode } from '@lexical/code'
import { LinkNode, AutoLinkNode } from '@lexical/link'
import {
  $convertFromMarkdownString,
  $convertToMarkdownString,
  TRANSFORMERS,
} from '@lexical/markdown'
import {
  EditorState,
  $getRoot,
  $getSelection,
  $isRangeSelection,
  COMMAND_PRIORITY_HIGH,
  COMMAND_PRIORITY_CRITICAL,
  HISTORY_MERGE_TAG,
  PASTE_COMMAND,
  KEY_ENTER_COMMAND,
  createCommand,
  LexicalCommand,
} from 'lexical'

const URL_MATCHER =
  /((https?:\/\/(www\.)?|www\.)[a-zA-Z0-9][-a-zA-Z0-9@:%._+~#=]{0,254}[a-zA-Z0-9]\.[a-z]{2,63}(\/[-a-zA-Z0-9@:%_+.~#?&/=]*)?)/

const MATCHERS = [
  (text: string) => {
    const match = URL_MATCHER.exec(text)
    if (!match) return null
    const fullMatch = match[0]
    return {
      index: match.index,
      length: fullMatch.length,
      text: fullMatch,
      url: fullMatch.startsWith('http') ? fullMatch : `https://${fullMatch}`,
    }
  },
]

export interface LexicalEditorHandle {
  focus: () => void
}

interface Props {
  initialContent: string
  onChange: (content: string) => void
  onEscape: () => void
  onAddFile: (file: File) => void
  onFocus?: () => void
  onBlur?: () => void
}

const theme = {
  paragraph: 'lexical-paragraph',
  text: {
    bold: 'lexical-bold',
    italic: 'lexical-italic',
    strikethrough: 'lexical-strikethrough',
    underline: 'lexical-underline',
    code: 'lexical-code',
  },
  heading: {
    h1: 'lexical-h1',
    h2: 'lexical-h2',
    h3: 'lexical-h3',
  },
  list: {
    ul: 'lexical-ul',
    ol: 'lexical-ol',
    listitem: 'lexical-li',
  },
  quote: 'lexical-quote',
  code: 'lexical-code-block',
  link: 'lexical-link',
}

function EscapePlugin({ onEscape }: { onEscape: () => void }) {
  const [editor] = useLexicalComposerContext()

  // Enter 키 처리 (Shift+Enter는 새 단락 삽입, Enter만 누르면 저장+나가기)
  useEffect(() => {
    return editor.registerCommand(
      KEY_ENTER_COMMAND,
      (event: KeyboardEvent | null) => {
        if (!event) return false
        // IME 조합 중이면 무시
        if (event.isComposing) return false

        // Shift+Enter는 새 단락 삽입 (마크다운에서 실제 줄바꿈으로 인식되도록)
        if (event.shiftKey) {
          event.preventDefault()
          editor.update(() => {
            const selection = $getSelection()
            if ($isRangeSelection(selection)) {
              // 현재 선택 영역을 삭제하고 새 단락 삽입
              selection.insertParagraph()
            }
          })
          return true
        }

        // Enter만 누르면 저장+나가기
        event.preventDefault()
        const rootElement = editor.getRootElement()
        rootElement?.blur()
        onEscape()
        return true
      },
      COMMAND_PRIORITY_CRITICAL
    )
  }, [editor, onEscape])

  // Escape 키 처리
  useEffect(() => {
    const rootElement = editor.getRootElement()
    if (!rootElement) return

    const handleKeyDown = (e: KeyboardEvent) => {
      // IME 조합 중이면 무시
      if (e.isComposing) return
      if (e.key !== 'Escape') return

      e.preventDefault()
      rootElement.blur()
      onEscape()
    }

    rootElement.addEventListener('keydown', handleKeyDown)
    return () => rootElement.removeEventListener('keydown', handleKeyDown)
  }, [editor, onEscape])

  return null
}

function FocusPlugin({
  editorRef,
}: {
  editorRef: React.MutableRefObject<{ focus: () => void } | null>
}) {
  const [editor] = useLexicalComposerContext()

  useEffect(() => {
    editorRef.current = {
      focus: () => editor.focus(),
    }
    return () => {
      editorRef.current = null
    }
  }, [editor, editorRef])

  return null
}

function InitialContentPlugin({ content }: { content: string }) {
  const [editor] = useLexicalComposerContext()
  const isInitializedRef = useRef(false)

  useEffect(() => {
    // 초기 마운트 시 한 번만 실행
    if (isInitializedRef.current) return
    isInitializedRef.current = true

    if (!content) return

    // HISTORY_MERGE_TAG를 달면 OnChangePlugin이 이 갱신을 흘려보낸다 —
    // 원문을 화면에 세우는 일이 저장으로 이어지면 안 된다 (BRU-66)
    editor.update(
      () => {
        $convertFromMarkdownString(content, TRANSFORMERS)
      },
      { tag: HISTORY_MERGE_TAG }
    )
  }, [content, editor])

  return null
}

const USER_INPUT_EVENTS = ['beforeinput', 'compositionstart', 'cut', 'paste', 'drop'] as const

// 사용자가 실제로 입력하기 전에는 본문을 저장하지 않는다 (BRU-66).
// 마운트·초기 파싱이 만드는 직렬화는 쓰기 경로에 절대 닿으면 안 된다.
function UserInputPlugin({ onUserInput }: { onUserInput: () => void }) {
  const [editor] = useLexicalComposerContext()

  useEffect(() => {
    return editor.registerRootListener((rootElement, prevRootElement) => {
      USER_INPUT_EVENTS.forEach((type) => {
        prevRootElement?.removeEventListener(type, onUserInput)
        rootElement?.addEventListener(type, onUserInput)
      })
    })
  }, [editor, onUserInput])

  return null
}

function LinkClickPlugin() {
  const [editor] = useLexicalComposerContext()

  useEffect(() => {
    const rootElement = editor.getRootElement()
    if (!rootElement) return

    const handleClick = (e: MouseEvent) => {
      const target = e.target as HTMLElement
      const link = target.closest('a')
      if (!link) return

      const href = link.getAttribute('href')
      if (!href) return

      e.preventDefault()
      window.api.openExternal(href)
    }

    rootElement.addEventListener('click', handleClick)
    return () => rootElement.removeEventListener('click', handleClick)
  }, [editor])

  return null
}

function FilePastePlugin({ onAddFile }: { onAddFile: (file: File) => void }) {
  const [editor] = useLexicalComposerContext()

  useEffect(() => {
    return editor.registerCommand(
      PASTE_COMMAND,
      (event: ClipboardEvent) => {
        const items = event.clipboardData?.items
        if (!items) return false

        // 파일 처리 (이미지 포함)
        for (const item of items) {
          if (item.kind === 'file') {
            const file = item.getAsFile()
            if (!file) continue

            event.preventDefault()
            onAddFile(file)
            return true
          }
        }

        return false
      },
      COMMAND_PRIORITY_HIGH
    )
  }, [editor, onAddFile])

  return null
}

// 타임스탬프 삽입 명령
const INSERT_TIMESTAMP_COMMAND: LexicalCommand<void> = createCommand('INSERT_TIMESTAMP_COMMAND')

function TimestampPlugin({ onUserInput }: { onUserInput: () => void }) {
  const [editor] = useLexicalComposerContext()

  useEffect(() => {
    const rootElement = editor.getRootElement()
    if (!rootElement) return

    const handleKeyDown = (e: KeyboardEvent) => {
      // Cmd+Shift+D (macOS) 또는 Ctrl+Shift+D (Windows/Linux)
      if ((e.metaKey || e.ctrlKey) && e.shiftKey && e.key.toLowerCase() === 'd') {
        e.preventDefault()
        editor.dispatchCommand(INSERT_TIMESTAMP_COMMAND, undefined)
      }
    }

    rootElement.addEventListener('keydown', handleKeyDown)
    return () => rootElement.removeEventListener('keydown', handleKeyDown)
  }, [editor])

  useEffect(() => {
    return editor.registerCommand(
      INSERT_TIMESTAMP_COMMAND,
      () => {
        const now = new Date()
        const timestamp = now.toLocaleString('ko-KR', {
          year: 'numeric',
          month: '2-digit',
          day: '2-digit',
          hour: '2-digit',
          minute: '2-digit',
          hour12: false,
        })

        // 프로그램이 넣는 텍스트지만 사용자가 시킨 편집이다 — 저장 게이트를 연다
        onUserInput()
        editor.update(() => {
          const selection = $getSelection()
          if ($isRangeSelection(selection)) {
            selection.insertText(`[${timestamp}] `)
          }
        })
        return true
      },
      COMMAND_PRIORITY_HIGH
    )
  }, [editor, onUserInput])

  return null
}

export const LexicalEditor = forwardRef<LexicalEditorHandle, Props>(
  ({ initialContent, onChange, onEscape, onAddFile, onFocus, onBlur }, ref) => {
    const editorRef = { current: null as { focus: () => void } | null }
    // 사용자가 이 에디터에 실제로 입력한 적이 있는가 (BRU-66)
    const hasUserInputRef = useRef(false)

    useImperativeHandle(ref, () => ({
      focus: () => editorRef.current?.focus(),
    }))

    const handleUserInput = useCallback(() => {
      hasUserInputRef.current = true
    }, [])

    const handleChange = useCallback(
      (editorState: EditorState) => {
        // 마운트·초기 파싱이 만든 직렬화는 저장으로 이어지지 않는다.
        // 열었다 닫기만 하면 원문은 손도 대지 않은 채로 남아야 한다.
        if (!hasUserInputRef.current) return

        editorState.read(() => {
          const root = $getRoot()
          if (root.getTextContent().length === 0 && root.getChildrenSize() <= 1) {
            onChange('')
            return
          }

          const markdown = $convertToMarkdownString(TRANSFORMERS)
          onChange(markdown)
        })
      },
      [onChange]
    )

    const initialConfig = {
      namespace: 'NoteEditor',
      theme,
      onError: (error: Error) => console.error(error),
      nodes: [HeadingNode, QuoteNode, ListNode, ListItemNode, CodeNode, LinkNode, AutoLinkNode],
    }

    return (
      <LexicalComposer initialConfig={initialConfig}>
        <div className="lexical-container" onFocus={onFocus} onBlur={onBlur}>
          <RichTextPlugin
            contentEditable={<ContentEditable className="lexical-content" />}
            placeholder={<div className="lexical-placeholder">메모 작성...</div>}
            ErrorBoundary={LexicalErrorBoundary}
          />
          <HistoryPlugin />
          <LinkPlugin />
          <AutoLinkPlugin matchers={MATCHERS} />
          <LinkClickPlugin />
          <MarkdownShortcutPlugin transformers={TRANSFORMERS} />
          <OnChangePlugin onChange={handleChange} />
          <FilePastePlugin onAddFile={onAddFile} />
          <TimestampPlugin onUserInput={handleUserInput} />
          <EscapePlugin onEscape={onEscape} />
          <FocusPlugin editorRef={editorRef} />
          <InitialContentPlugin content={initialContent} />
          <UserInputPlugin onUserInput={handleUserInput} />
        </div>
      </LexicalComposer>
    )
  }
)

LexicalEditor.displayName = 'LexicalEditor'
