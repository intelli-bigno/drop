# PRD — DROP

> "생각을 떠올리는 즉시 어디서든 기록하고, 하나의 공간에서 관리"

> **[2026-08-13 갱신 · BRU-22]** 아래 본문은 작성 시점(Flutter 기준) 원문을 그대로 둔다.
> 현재 구현은 다르다 — 모바일은 **SwiftUI 네이티브(`apps/ios`)** 단일 트랙이고 Flutter 앱 `apps/mobile`은 제거됐다.
> **Android 앱은 현재 없다** (재개 여부는 BRU-33). 실제 스택·명령은 `README.md`와 `apps/ios/README.md`가 정본이다.

---

## 1. Product Overview

| 항목 | 내용 |
|------|------|
| 제품명 | DROP |
| 구성요소 | iOS/Android (Flutter), Desktop (Electron), Supabase Backend |
| 핵심 가치 | Markdown 노트 + 실시간 동기화 |
| 목표 사용자 | 빠른 기록 + 멀티 디바이스 사용자 |
| 제품 원칙 | 빠름 · 단순 · Supabase SSoT |

---

## 2. Tech Stack

| 영역 | Mobile (Flutter) | Desktop (Electron) |
|------|------------------|-------------------|
| Framework | Flutter 3.x | Electron + React |
| Language | Dart | TypeScript |
| State | Riverpod | Zustand |
| Editor | WebView + Lexical | Lexical |
| Audio/STT | record + Whisper API | - |

**Backend (SSoT)**: Supabase (PostgreSQL + Realtime + Storage)

---

## 3. Data Model

### 3.1 아키텍처

```
[Mobile/Desktop App] → [Supabase JS Client] → [Supabase (SSoT)]
                                                    ├── PostgreSQL
                                                    ├── Storage (첨부파일)
                                                    └── Realtime (실시간 동기화)
```

- **SSoT (Single Source of Truth)**: 모든 데이터는 Supabase에 직접 저장
- **Realtime**: Supabase Realtime으로 디바이스 간 실시간 동기화
- **Storage**: 첨부파일은 Supabase Storage에 저장

### 3.2 Schema

```sql
-- Notes table
CREATE TABLE notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content TEXT,
  parent_id UUID REFERENCES notes(id) ON DELETE CASCADE,  -- 스레드/답글 지원
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  source TEXT NOT NULL CHECK (source IN ('mobile', 'desktop', 'web')),
  is_deleted BOOLEAN DEFAULT false
);

-- Attachments table
CREATE TABLE attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id UUID NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('image', 'audio', 'video', 'file', 'text', 'instagram')),
  storage_path TEXT NOT NULL,
  filename TEXT,
  mime_type TEXT,
  size INTEGER,
  metadata JSONB,                    -- 추가 메타데이터 (Instagram 미디어 정보 등)
  original_url TEXT,                 -- Instagram 원본 URL
  author_name TEXT,                  -- Instagram 작성자명
  author_url TEXT,                   -- Instagram 작성자 프로필 URL
  caption TEXT,                      -- Instagram 캡션
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tags table
CREATE TABLE tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Note-Tags junction table
CREATE TABLE note_tags (
  note_id UUID NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (note_id, tag_id)
);

-- Indexes
CREATE INDEX idx_attachments_note_id ON attachments(note_id);
CREATE INDEX idx_notes_created_at ON notes(created_at DESC);
CREATE INDEX idx_notes_is_deleted ON notes(is_deleted);
CREATE INDEX idx_notes_parent_id ON notes(parent_id) WHERE parent_id IS NOT NULL;

-- Updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER notes_updated_at
  BEFORE UPDATE ON notes
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();
```

### 3.3 Type Definitions

```typescript
// 공유 타입 정의 (@drop/shared)

type NoteSource = 'mobile' | 'desktop' | 'web'
type AttachmentType = 'image' | 'audio' | 'video' | 'file' | 'text' | 'instagram'

// Database Row Types (snake_case)
interface NoteRow {
  id: string
  content: string | null
  parent_id: string | null
  created_at: string          // ISO 8601
  updated_at: string          // ISO 8601
  source: NoteSource
  is_deleted: boolean
}

interface AttachmentRow {
  id: string
  note_id: string
  type: AttachmentType
  storage_path: string
  filename: string | null
  mime_type: string | null
  size: number | null
  metadata: Record<string, unknown> | null
  original_url: string | null
  author_name: string | null
  author_url: string | null
  caption: string | null
  created_at: string
}

interface TagRow {
  id: string
  name: string
  created_at: string
}

// Application Types (camelCase)
interface Note {
  id: string
  content: string
  parentId: string | null
  attachments: Attachment[]
  tags: Tag[]
  createdAt: Date
  updatedAt: Date
  source: NoteSource
  isDeleted: boolean
}

interface Attachment {
  id: string
  noteId: string
  type: AttachmentType
  storagePath: string
  filename?: string
  mimeType?: string
  size?: number
  metadata?: Record<string, unknown>
  originalUrl?: string
  authorName?: string
  authorUrl?: string
  caption?: string
  createdAt: Date
}

interface Tag {
  id: string
  name: string
  createdAt: Date
}
```

---

## 4. Features

### 4.1 Desktop 구현 완료

#### 4.1.1 노트 피드
- 날짜별 그룹화 (한국어 포맷: "2025년 12월 22일")
- 무한 스크롤
- 드래그 앤 드롭으로 파일 첨부
- 키보드 네비게이션 (j/k)

#### 4.1.2 스레드/답글 시스템
- 노트에 답글 추가 (parent_id로 연결)
- 들여쓰기 UI (depth * 24px)
- 왼쪽 border로 시각적 연결
- 자식 노트는 생성일 오름차순 정렬 (대화 순서 유지)
- 답글 버튼 (↩) + Shift+Enter 단축키

**트리 구조 처리:**
```typescript
// 1. 루트 노트만 추출 (parentId === null)
const rootNotes = notes.filter(note => note.parentId === null)

// 2. 자식 노트 맵 생성
const childrenMap = new Map<string, Note[]>()
for (const note of notes) {
  if (note.parentId) {
    const children = childrenMap.get(note.parentId) || []
    children.push(note)
    childrenMap.set(note.parentId, children)
  }
}

// 3. 재귀적으로 평탄화 (depth 포함)
function flattenWithDepth(noteList: Note[], depth: number): Array<{note: Note, depth: number}> {
  const result = []
  for (const note of noteList) {
    result.push({ note, depth })
    const children = childrenMap.get(note.id) || []
    // 자식은 생성일 오름차순
    const sorted = children.sort((a, b) => a.createdAt - b.createdAt)
    result.push(...flattenWithDepth(sorted, depth + 1))
  }
  return result
}
```

#### 4.1.3 Lexical 에디터
- Markdown 지원 (bold, italic, code, list, quote 등)
- 자동 링크 감지 (AutoLinkPlugin)
- 링크 클릭 시 시스템 브라우저로 열기
- 이미지/파일 붙여넣기 (Cmd+V)
- Escape로 포커스 해제

#### 4.1.4 첨부파일 시스템

**지원 타입:**

| type | 설명 | UI |
|------|------|-----|
| `image` | 이미지 파일 | 썸네일 + 클릭 시 확대 |
| `video` | 비디오 파일 | 썸네일 + 클릭 시 확대 |
| `audio` | 오디오 파일 | 파일 아이콘 + 이름 |
| `file` | 기타 파일 | 파일 아이콘 + 이름 + 크기 |
| `text` | 대용량 텍스트 | 프리뷰 + 펼치기 |
| `instagram` | Instagram 게시물 | 썸네일 + 작성자 + 캡션 |

**Storage 경로 규칙:**
```
{note_id}/{uuid}.{extension}
예: abc123/def456.jpg
```

**텍스트 첨부 판단 기준:**
- 20줄 이상 AND 1000자 이상일 때 텍스트 첨부파일로 처리
- 그 외는 노트 본문으로 삽입

#### 4.1.5 Instagram 임베드

**URL 파싱:**
```typescript
// 지원 도메인
const INSTAGRAM_HOSTS = ['instagram.com', 'www.instagram.com', 'instagr.am']

// 지원 경로
const INSTAGRAM_PATH_TYPES = ['p', 'reel', 'reels', 'tv']

// URL 패턴
// https://www.instagram.com/p/SHORTCODE/
// https://www.instagram.com/reel/SHORTCODE/
// https://www.instagram.com/share/p/SHORTCODE/

// 정규화
function normalizeInstagramUrl(raw: string): string | null {
  const url = new URL(raw)
  // host 검증, path 추출, shortcode 추출
  // 결과: https://www.instagram.com/p/SHORTCODE/
}
```

**메타데이터 가져오기:**
1. `https://www.instagram.com/p/{shortcode}/?__a=1&__d=dis` API 호출
2. 헤더: `User-Agent`, `Accept`, `Referer` 필수
3. 응답에서 `graphql.shortcode_media` 추출

**저장 구조:**
```typescript
{
  type: 'instagram',
  storagePath: 'instagram/{shortcode}',  // 실제 저장 안함
  originalUrl: 'https://www.instagram.com/p/SHORTCODE/',
  authorName: '@username',
  authorUrl: 'https://www.instagram.com/username/',
  caption: '게시물 캡션...',
  metadata: {
    shortcode: 'SHORTCODE',
    mediaType: 'image' | 'video' | 'carousel',
    thumbnailUrl: 'https://...',
    displayUrl: 'https://...',
    mediaUrls: ['https://...'],  // 캐러셀의 경우 여러 개
    // ... 기타 메타데이터
  }
}
```

**자동 태그:**
- Instagram URL로 노트 생성 시 "인스타그램" 태그 자동 추가

#### 4.1.6 태그 시스템

**태그 추가:**
1. 태그 입력창에 이름 입력
2. 기존 태그 자동완성 제안
3. Enter로 선택/생성
4. 존재하지 않는 태그는 자동 생성 (upsert)

**태그 필터:**
- 태그 클릭 시 해당 태그가 있는 노트만 표시
- 헤더에 필터 표시 + X 버튼으로 해제

**태그 다이얼로그:**
- Cmd+Shift+T로 열기
- 전체 태그 목록 + 검색
- 체크박스로 다중 선택

#### 4.1.7 붙여넣기 동작

| 클립보드 내용 | 동작 |
|--------------|------|
| 파일/이미지 | 새 노트 생성 + 첨부 |
| Instagram URL | 새 노트 생성 + Instagram 임베드 + "인스타그램" 태그 |
| 대용량 텍스트 (20줄+ AND 1000자+) | 새 노트 생성 + 텍스트 첨부 |
| 일반 텍스트 | 새 노트 생성 + 본문에 삽입 |

**조건:** 에디터에 포커스가 없을 때만 글로벌 붙여넣기 적용

---

## 5. Keyboard Shortcuts

### 5.1 글로벌

| 단축키 | 동작 | 컨텍스트 |
|--------|------|----------|
| `Cmd+N` | 새 노트 생성 | 전역 |
| `Cmd+Shift+T` | 태그 다이얼로그 열기 | 노트 선택/편집 중 |

### 5.2 피드 네비게이션

| 단축키 | 동작 |
|--------|------|
| `j` / `↓` / `ㅓ` | 다음 노트로 이동 |
| `k` / `↑` / `ㅏ` | 이전 노트로 이동 |
| `Enter` | 선택된 노트 편집 모드 |
| `Shift+Enter` | 선택된 노트에 답글 작성 |
| `Delete` / `Backspace` | 선택된 노트 삭제 (확인 필요) |
| `Escape` | 선택 해제 |

**한글 IME 지원:** j/k가 한글 모드에서 ㅓ/ㅏ로 입력되는 경우 처리

### 5.3 에디터

| 단축키 | 동작 |
|--------|------|
| `Escape` | 편집 모드 종료, 피드로 포커스 이동 |
| `Cmd+V` | 파일/이미지 붙여넣기 |

---

## 6. UI/UX Patterns

### 6.1 시간 표시

```typescript
function formatRelativeTime(date: Date): string {
  const now = new Date()
  const diff = now.getTime() - date.getTime()
  const seconds = Math.floor(diff / 1000)
  const minutes = Math.floor(seconds / 60)
  const hours = Math.floor(minutes / 60)

  if (seconds < 60) return `${seconds}초전`
  if (minutes < 60) return `${minutes}분전`

  const isToday = date.toDateString() === now.toDateString()
  const yesterday = new Date(now)
  yesterday.setDate(yesterday.getDate() - 1)
  const isYesterday = date.toDateString() === yesterday.toDateString()

  const time = date.toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit', hour12: false })

  if (isToday) return `오늘 ${time}`
  if (isYesterday) return `어제 ${time}`

  return date.toLocaleDateString('ko-KR', { year: 'numeric', month: 'long', day: 'numeric' })
}
```

### 6.2 외부 링크 처리

**중요:** 모든 외부 링크는 시스템 브라우저에서 열어야 함

```typescript
// Electron에서 window.open()을 사용하면 새 Electron 창이 열림
// 반드시 shell.openExternal() 사용

// Main process
ipcMain.handle('shell:openExternal', async (_event, url: string) => {
  await shell.openExternal(url)
})

// Renderer (preload에서 노출)
window.api.openExternal(url)
```

### 6.3 드래그 앤 드롭

```typescript
function useDragAndDrop(options: { onDrop: (files: File[]) => void }) {
  const [isDragOver, setIsDragOver] = useState(false)

  const handleDragOver = (e: DragEvent) => {
    e.preventDefault()
    setIsDragOver(true)
  }

  const handleDragLeave = (e: DragEvent) => {
    e.preventDefault()
    setIsDragOver(false)
  }

  const handleDrop = (e: DragEvent) => {
    e.preventDefault()
    setIsDragOver(false)
    const files = Array.from(e.dataTransfer?.files || [])
    if (files.length > 0) {
      options.onDrop(files)
    }
  }

  return { isDragOver, handleDragOver, handleDragLeave, handleDrop }
}
```

### 6.4 Skeleton Loading

Instagram 메타데이터 로딩 중 표시:
```css
.attachment-skeleton {
  background: linear-gradient(90deg, var(--bg-secondary) 25%, var(--bg-card) 50%, var(--bg-secondary) 75%);
  background-size: 200% 100%;
  animation: skeleton-shimmer 1.5s infinite;
}

@keyframes skeleton-shimmer {
  0% { background-position: 200% 0; }
  100% { background-position: -200% 0; }
}
```

---

## 7. API Patterns

### 7.1 Optimistic Updates

```typescript
// 예: 노트 생성
async function createNote(initialContent = '', parentId?: string) {
  const id = crypto.randomUUID()
  const now = new Date()

  // 1. Optimistic update (즉시 UI 반영)
  const optimisticNote = {
    id,
    content: initialContent,
    parentId: parentId ?? null,
    attachments: [],
    tags: [],
    createdAt: now,
    updatedAt: now,
    source: 'desktop',
    isDeleted: false,
  }
  set(state => ({ notes: [optimisticNote, ...state.notes] }))

  // 2. 서버에 저장
  const { data, error } = await supabase.from('notes').insert({
    id,
    content: initialContent,
    parent_id: parentId ?? null,
    source: 'desktop',
  }).select().single()

  // 3. 에러 시 롤백
  if (error) {
    set(state => ({ notes: state.notes.filter(n => n.id !== id) }))
    throw error
  }

  // 4. 서버 응답으로 교체
  set(state => ({
    notes: state.notes.map(n => n.id === id ? noteRowToNote(data) : n)
  }))

  return noteRowToNote(data)
}
```

### 7.2 Realtime 구독

```typescript
function subscribeToChanges() {
  const channel = supabase
    .channel('notes-changes')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'notes' },
      async (payload) => {
        const { eventType, new: newRow, old: oldRow } = payload

        if (eventType === 'INSERT') {
          // 로컬에서 생성한 노트는 무시 (이미 optimistic update됨)
          if (state.notes.some(n => n.id === newRow.id)) return
          // 외부에서 생성된 노트 추가
          set(state => ({ notes: [noteRowToNote(newRow), ...state.notes] }))
        }

        if (eventType === 'UPDATE') {
          if (newRow.is_deleted) {
            // soft delete
            set(state => ({ notes: state.notes.filter(n => n.id !== newRow.id) }))
          } else {
            // 내용 업데이트
            set(state => ({
              notes: state.notes.map(n =>
                n.id === newRow.id ? { ...n, content: newRow.content, updatedAt: new Date(newRow.updated_at) } : n
              )
            }))
          }
        }

        if (eventType === 'DELETE') {
          set(state => ({ notes: state.notes.filter(n => n.id !== oldRow.id) }))
        }
      }
    )
    .subscribe()

  return () => supabase.removeChannel(channel)
}
```

### 7.3 태그 Upsert

```typescript
async function addTagToNote(noteId: string, tagName: string) {
  // 1. 태그 upsert (없으면 생성)
  const { data: tagData } = await supabase
    .from('tags')
    .upsert({ name: tagName }, { onConflict: 'name' })
    .select()
    .single()

  // 2. note_tags에 연결
  await supabase
    .from('note_tags')
    .upsert({ note_id: noteId, tag_id: tagData.id })

  // 3. 로컬 상태 업데이트
  set(state => ({
    notes: state.notes.map(n =>
      n.id === noteId
        ? { ...n, tags: [...n.tags, tagRowToTag(tagData)] }
        : n
    )
  }))
}
```

---

## 8. MVP Scope (v1.0)

### Phase 1: Desktop ✅
- [x] Electron + React + Lexical 세팅
- [x] Supabase 연동 (SSoT)
- [x] 노트 CRUD + Realtime 동기화
- [x] 첨부파일 업로드 (Storage)
- [x] 태그 시스템
- [x] Instagram 임베드
- [x] 텍스트 첨부파일
- [x] 스레드/답글 시스템
- [x] 키보드 단축키

### Phase 2: Mobile
- [ ] Flutter 세팅
- [ ] Supabase 연동
- [ ] 노트 목록/상세 화면
- [ ] 스레드 UI (들여쓰기)
- [ ] 음성 녹음 + Whisper STT
- [ ] 이미지, 비디오 첨부
- [ ] Instagram URL 붙여넣기

### Phase 3: Polish
- [ ] 검색 기능
- [ ] UI/UX 개선
- [ ] 오프라인 지원 (로컬 캐시)

### v2
- 사용자 인증
- iOS/Android 위젯
- 공유 기능

---

## 9. KPIs

| 목표 | 지표 |
|------|------|
| 빠른 기록 | 노트 생성 < 3초 |
| STT 정확도 | Whisper 성공률 95%+ |
| 실시간 동기화 | 디바이스 간 반영 < 3초 |
| 앱 안정성 | Crash-free rate 99%+ |

---

*Last Updated: 2025-12-22*
