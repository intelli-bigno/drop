/// <reference path="../../preload/index.d.ts" />
import { forwardRef, useImperativeHandle, useEffect, useCallback, useRef, useState } from 'react'
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
import { $isCodeNode, CodeNode } from '@lexical/code'
import {
  LinkNode,
  AutoLinkNode,
  TOGGLE_LINK_COMMAND,
  $isLinkNode,
  $createLinkNode,
  $toggleLink,
} from '@lexical/link'
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
  HISTORY_MERGE_TAG,
  PASTE_COMMAND,
  KEY_ENTER_COMMAND,
  KEY_DOWN_COMMAND,
  $createTextNode,
  $setSelection,
  type BaseSelection,
  createCommand,
  LexicalCommand,
} from 'lexical'
import { decideEditorEnter } from '../lib/editor-enter'
import { normalizeLinkInput, resolveLinkAction } from '../lib/link-shortcut'
import { Icon } from './Icon'
import { matchesKey } from '../shortcuts/keys'
import { useToastStore } from '../stores/toast'
import { applyCaretScroll } from '../lib/editor-caret-scroll'

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

  // Enter는 줄을 넣는다. 편집 종료는 Esc (BRU-134).
  // 코드 블록 안에서는 노드를 쪼개지 않고 줄만 넣는다 (BRU-130).
  useEffect(() => {
    return editor.registerCommand(
      KEY_ENTER_COMMAND,
      (event: KeyboardEvent | null) => {
        const selection = $getSelection()
        const inCodeBlock =
          $isRangeSelection(selection) &&
          $isCodeNode(selection.anchor.getNode().getTopLevelElement())
        const action = decideEditorEnter({
          isComposing: Boolean(event?.isComposing),
          inCodeBlock,
        })
        if (action !== 'insertLine') return false

        event?.preventDefault()
        if ($isRangeSelection(selection)) {
          selection.insertLineBreak()
        }
        return true
      },
      COMMAND_PRIORITY_HIGH
    )
  }, [editor])

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

function CaretScrollPlugin() {
  const [editor] = useLexicalComposerContext()

  useEffect(() => {
    return editor.registerUpdateListener(({ tags }) => {
      if (tags.has(HISTORY_MERGE_TAG)) return
      const root = editor.getRootElement()
      const container = root?.closest('.note-editor')
      if (!root || !(container instanceof HTMLElement)) return

      const native = window.getSelection()
      if (!native || native.rangeCount === 0 || !root.contains(native.anchorNode)) return
      const range = native.getRangeAt(0)
      const rect = range.getBoundingClientRect()
      if (rect.height === 0 && rect.width === 0) return

      const containerRect = container.getBoundingClientRect()
      applyCaretScroll(container, {
        offsetTop: rect.top - containerRect.top + container.scrollTop,
        height: Math.max(rect.height, 1),
      })
    })
  }, [editor])

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

/**
 * ⌘K — 링크 걸기 (BRU-213).
 *
 * 글을 쓰는 자리에서 ⌘K는 어느 앱에서나 「링크 걸기」다(Word · Docs · Notion ·
 * Slack 입력창). 그래서 검색을 ⌘O 하나로 모으고 이 자리를 편집기에 돌려줬다.
 *
 * 처음에는 **클립보드를 읽어** 창 없이 걸려고 했다. 실제 손버릇이 「주소를
 * 복사하고 → 글자를 골라 → ⌘K」라서 물어볼 것이 없다고 봤는데, 두 가지가
 * 걸렸다: `navigator.clipboard.readText()`는 권한을 묻느라 **응답 없이 멈출 수
 * 있고**(실측으로 브라우저가 얼어붙었다), 아직 주소를 복사하지 않은 사람에게는
 * 막다른 길이다. 그래서 작은 입력줄을 연다 — 물어보는 편이 정직하다.
 *
 * 고른 자리는 입력줄로 초점이 옮겨가는 순간 사라지므로 **미리 복제해 둔다.**
 */
function LinkShortcutPlugin({ onUserInput }: { onUserInput: () => void }) {
  const [editor] = useLexicalComposerContext()
  const [isOpen, setIsOpen] = useState(false)
  const [value, setValue] = useState('')
  const savedSelection = useRef<BaseSelection | null>(null)
  const inputRef = useRef<HTMLInputElement>(null)

  const close = useCallback(() => {
    setIsOpen(false)
    setValue('')
    savedSelection.current = null
    editor.focus()
  }, [editor])

  useEffect(() => {
    return editor.registerCommand(
      KEY_DOWN_COMMAND,
      (event: KeyboardEvent) => {
        if (!(event.metaKey || event.ctrlKey) || event.altKey) return false
        if (!matchesKey('insertLink', event.key.toLowerCase())) return false
        event.preventDefault()

        let selectedText = ''
        let isLink = false
        editor.getEditorState().read(() => {
          const selection = $getSelection()
          savedSelection.current = selection ? selection.clone() : null
          if (!$isRangeSelection(selection)) return
          selectedText = selection.getTextContent()
          const node = selection.anchor.getNode()
          isLink = $isLinkNode(node) || $isLinkNode(node.getParent())
        })

        // 이미 링크인 자리에서는 묻지 않는다 — ⌘K는 켜고 끄는 글쇠다.
        if (resolveLinkAction({ selectedText, clipboardText: '', isLink }).type === 'unlink') {
          editor.dispatchCommand(TOGGLE_LINK_COMMAND, null)
          onUserInput()
          useToastStore.getState().showToast({ message: '링크를 풀었다', duration: 1800 })
          return true
        }

        // 고른 글자가 그 자체로 주소면 물어볼 것이 없다.
        const direct = resolveLinkAction({ selectedText, clipboardText: '', isLink })
        if (direct.type === 'link') {
          editor.dispatchCommand(TOGGLE_LINK_COMMAND, direct.url)
          onUserInput()
          useToastStore.getState().showToast({ message: '링크를 걸었다', icon: 'link', duration: 1800 })
          return true
        }

        setValue('')
        setIsOpen(true)
        requestAnimationFrame(() => inputRef.current?.focus())
        return true
      },
      COMMAND_PRIORITY_HIGH
    )
  }, [editor, onUserInput])

  const apply = useCallback(() => {
    const url = normalizeLinkInput(value)
    if (!url) {
      useToastStore.getState().showToast({ message: '주소로 볼 수 없다', variant: 'error' })
      return
    }

    const selection = savedSelection.current
    editor.update(() => {
      // 입력줄로 초점이 옮겨가면서 사라진 선택을 되돌려 놓고 건다.
      if (selection) $setSelection(selection.clone())
      const current = $getSelection()
      if ($isRangeSelection(current) && current.isCollapsed()) {
        // 고른 글자가 없다 — 주소를 글자로 지어 넣는다. 빈 선택에 링크를 걸면
        // 걸 자리가 없어서 아무 일도 일어나지 않는다.
        const link = $createLinkNode(url)
        link.append($createTextNode(url))
        current.insertNodes([link])
        return
      }
      $toggleLink(url)
    })

    // 링크를 거는 것은 **사람의 입력**이다 (BRU-213). 이 편집기는 저장을
    // `USER_INPUT_EVENTS`(beforeinput·paste 따위)로만 열어 두는데(BRU-66),
    // ⌘K는 그중 어느 것도 일으키지 않는다 — 알리지 않으면 방금 건 링크가
    // 화면에는 보이는데 저장은 되지 않는다. 실측으로 걸렸다.
    onUserInput()
    useToastStore.getState().showToast({ message: '링크를 걸었다', icon: 'link', duration: 1800 })
    close()
  }, [editor, value, close, onUserInput])

  if (!isOpen) return null

  return (
    <div className="link-input" role="group" aria-label="링크 주소">
      <Icon name="link" size={14} className="link-input-icon" />
      <input
        ref={inputRef}
        type="text"
        className="link-input-field"
        placeholder="주소를 붙여넣고 Enter"
        value={value}
        onChange={(e) => setValue(e.target.value)}
        onKeyDown={(e) => {
          e.stopPropagation()
          if (e.key === 'Enter') {
            e.preventDefault()
            apply()
          }
          if (e.key === 'Escape') {
            e.preventDefault()
            close()
          }
        }}
      />
      <span className="link-input-help">
        <kbd>Enter</kbd> 걸기 <kbd>Esc</kbd> 취소
      </span>
    </div>
  )
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
          <LinkShortcutPlugin onUserInput={handleUserInput} />
          <MarkdownShortcutPlugin transformers={TRANSFORMERS} />
          <OnChangePlugin onChange={handleChange} />
          <FilePastePlugin onAddFile={onAddFile} />
          <TimestampPlugin onUserInput={handleUserInput} />
          <EscapePlugin onEscape={onEscape} />
          <CaretScrollPlugin />
          <FocusPlugin editorRef={editorRef} />
          <InitialContentPlugin content={initialContent} />
          <UserInputPlugin onUserInput={handleUserInput} />
        </div>
      </LexicalComposer>
    )
  }
)

LexicalEditor.displayName = 'LexicalEditor'
