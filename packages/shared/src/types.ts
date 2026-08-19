// PRD 3.2 Schema 기반 타입 정의

// 'mcp' = MCP 서버(AI 어시스턴트)를 통해 만들어진 노트
export type NoteSource = 'mobile' | 'desktop' | 'web' | 'mcp'

export type AttachmentType = 'image' | 'audio' | 'video' | 'file' | 'text' | 'instagram' | 'youtube' | 'book'

// Database row types (snake_case - Supabase 컬럼명과 일치)
export interface NoteRow {
  id: string
  display_id: number
  content: string | null
  parent_id: string | null
  created_at: string
  updated_at: string
  source: NoteSource
  is_deleted: boolean
  user_id: string | null
  // 카테고리 플래그
  has_link: boolean
  has_media: boolean
  has_files: boolean
  // 잠금
  is_locked: boolean
  deleted_at: string | null
  archived_at: string | null
  priority: number
  // 상단 고정
  is_pinned: boolean
  pinned_at: string | null
  // Linear 반출 (BRU-45)
  linear_issue_url: string | null
  linear_issue_key: string | null
  linear_exported_at: string | null
  // 프로젝트 (BRU-83). NULL이면 미분류
  project_id: string | null
}

export interface AttachmentRow {
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

export interface TagRow {
  id: string
  name: string
  created_at: string
  user_id: string | null
  last_used_at: string | null
}

export interface NoteTagRow {
  note_id: string
  tag_id: string
}

export interface UserProfileRow {
  id: string
  user_id: string
  pin_hash: string | null
  created_at: string
  updated_at: string
}

export interface UserProfile {
  id: string
  userId: string
  hasPin: boolean
  createdAt: Date
  updatedAt: Date
}

// Application types (camelCase - 앱 내부 사용)
export interface Note {
  id: string
  displayId: number
  content: string
  parentId: string | null
  attachments: Attachment[]
  tags: Tag[]
  createdAt: Date
  updatedAt: Date
  source: NoteSource
  isDeleted: boolean
  // 카테고리 플래그
  hasLink: boolean
  hasMedia: boolean
  hasFiles: boolean
  // 잠금
  isLocked: boolean
  deletedAt: Date | null
  archivedAt: Date | null
  priority: number
  // 상단 고정
  isPinned: boolean
  pinnedAt: Date | null
  // Linear 반출 (BRU-45). URL이 있으면 반출된 노트다 — 세 값은 함께 채워진다.
  linearIssueUrl: string | null
  linearIssueKey: string | null
  linearExportedAt: Date | null
  /** 이 노트가 속한 프로젝트 (BRU-83). null이면 미분류. 노트는 프로젝트 하나에만 속한다. */
  projectId: string | null
}

export interface Attachment {
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

export interface Tag {
  id: string
  name: string
  createdAt: Date
  lastUsedAt: Date | null
}

// Input types
export interface CreateNoteInput {
  content: string
  source: NoteSource
}

export interface UpdateNoteInput {
  content?: string
}

export interface CreateAttachmentInput {
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
}

// Row <-> App type 변환 함수
export function tagRowToTag(row: TagRow): Tag {
  return {
    id: row.id,
    name: row.name,
    createdAt: new Date(row.created_at),
    lastUsedAt: row.last_used_at ? new Date(row.last_used_at) : null,
  }
}

export function noteRowToNote(
  row: NoteRow,
  attachments: Attachment[] = [],
  tags: Tag[] = []
): Note {
  return {
    id: row.id,
    displayId: row.display_id,
    content: row.content ?? '',
    parentId: row.parent_id,
    attachments,
    tags,
    createdAt: new Date(row.created_at),
    updatedAt: new Date(row.updated_at),
    source: row.source,
    isDeleted: row.is_deleted,
    hasLink: row.has_link,
    hasMedia: row.has_media,
    hasFiles: row.has_files,
    isLocked: row.is_locked,
    deletedAt: row.deleted_at ? new Date(row.deleted_at) : null,
    archivedAt: row.archived_at ? new Date(row.archived_at) : null,
    priority: row.priority ?? 0,
    isPinned: row.is_pinned ?? false,
    pinnedAt: row.pinned_at ? new Date(row.pinned_at) : null,
    linearIssueUrl: row.linear_issue_url ?? null,
    linearIssueKey: row.linear_issue_key ?? null,
    linearExportedAt: row.linear_exported_at ? new Date(row.linear_exported_at) : null,
    projectId: row.project_id ?? null,
  }
}

export function userProfileRowToUserProfile(row: UserProfileRow): UserProfile {
  return {
    id: row.id,
    userId: row.user_id,
    hasPin: Boolean(row.pin_hash),
    createdAt: new Date(row.created_at),
    updatedAt: new Date(row.updated_at),
  }
}

export function attachmentRowToAttachment(row: AttachmentRow): Attachment {
  return {
    id: row.id,
    noteId: row.note_id,
    type: row.type,
    storagePath: row.storage_path,
    filename: row.filename ?? undefined,
    mimeType: row.mime_type ?? undefined,
    size: row.size ?? undefined,
    metadata: row.metadata ?? undefined,
    originalUrl: row.original_url ?? undefined,
    authorName: row.author_name ?? undefined,
    authorUrl: row.author_url ?? undefined,
    caption: row.caption ?? undefined,
    createdAt: new Date(row.created_at),
  }
}
