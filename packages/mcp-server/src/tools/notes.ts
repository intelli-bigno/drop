import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js'
import { z } from 'zod'
import { callMcpRpc } from '../supabase.js'

interface Note {
  id: string
  display_id: number
  content: string
  source: string
  parent_id: string | null
  is_locked: boolean
  has_link: boolean
  has_media: boolean
  has_files: boolean
  created_at: string
  updated_at: string
  deleted_at: string | null
  archived_at: string | null
  linear_issue_url?: string | null
  linear_issue_key?: string | null
  linear_exported_at?: string | null
  tags?: Array<{ id: string; name: string }>
  attachments?: Array<{
    id: string
    type: string
    filename: string | null
    mime_type: string | null
    size: number | null
    storage_path: string | null
  }>
}

interface ListNotesResult {
  notes: Note[]
  total: number
}

interface SuccessResult {
  success: boolean
  note_id: string
}

export function registerNotesTools(server: McpServer) {
  server.tool(
    'list_notes',
    'List recent notes from DROP',
    {
      limit: z.number().min(1).max(100).default(20).describe('Number of notes to return'),
      offset: z.number().min(0).default(0).describe('Offset for pagination'),
      includeDeleted: z.boolean().default(false).describe('Include soft-deleted notes'),
      includeArchived: z.boolean().default(false).describe('Include archived notes'),
    },
    async ({ limit, offset, includeDeleted, includeArchived }) => {
      try {
        const result = await callMcpRpc<ListNotesResult>('mcp_list_notes', {
          p_limit: limit,
          p_offset: offset,
          p_include_deleted: includeDeleted,
          p_include_archived: includeArchived,
        })

        const notes = result.notes.map((note) => ({
          id: note.id,
          displayId: note.display_id,
          content: note.content,
          source: note.source,
          parentId: note.parent_id,
          isLocked: note.is_locked,
          hasLink: note.has_link,
          hasMedia: note.has_media,
          hasFiles: note.has_files,
          createdAt: note.created_at,
          updatedAt: note.updated_at,
          isDeleted: !!note.deleted_at,
          isArchived: !!note.archived_at,
          // 이미 Linear로 나간 노트인지. 없으면 같은 노트를 두 번 반출하게 된다 (BRU-45).
          exportedTo: note.linear_issue_url ?? null,
          exportedKey: note.linear_issue_key ?? null,
          exportedAt: note.linear_exported_at ?? null,
        }))

        return {
          content: [
            {
              type: 'text' as const,
              text: JSON.stringify(
                { notes, total: result.total, hasMore: offset + limit < result.total },
                null,
                2
              ),
            },
          ],
        }
      } catch (err) {
        return {
          content: [{ type: 'text' as const, text: `Error: ${(err as Error).message}` }],
          isError: true,
        }
      }
    }
  )

  server.tool(
    'get_note',
    'Get a single note with its tags and attachments',
    {
      noteId: z.string().uuid().describe('The UUID of the note'),
    },
    async ({ noteId }) => {
      try {
        const note = await callMcpRpc<Note>('mcp_get_note', { p_note_id: noteId })

        const result = {
          id: note.id,
          displayId: note.display_id,
          content: note.content,
          source: note.source,
          parentId: note.parent_id,
          isLocked: note.is_locked,
          hasLink: note.has_link,
          hasMedia: note.has_media,
          hasFiles: note.has_files,
          createdAt: note.created_at,
          updatedAt: note.updated_at,
          isDeleted: !!note.deleted_at,
          isArchived: !!note.archived_at,
          exportedTo: note.linear_issue_url ?? null,
          exportedKey: note.linear_issue_key ?? null,
          exportedAt: note.linear_exported_at ?? null,
          tags: note.tags || [],
          attachments:
            note.attachments?.map((a) => ({
              id: a.id,
              type: a.type,
              filename: a.filename,
              mimeType: a.mime_type,
              size: a.size,
            })) || [],
        }

        return {
          content: [{ type: 'text' as const, text: JSON.stringify(result, null, 2) }],
        }
      } catch (err) {
        return {
          content: [{ type: 'text' as const, text: `Error: ${(err as Error).message}` }],
          isError: true,
        }
      }
    }
  )

  server.tool(
    'create_note',
    'Create a new note',
    {
      content: z.string().describe('The content of the note'),
      parentId: z.string().uuid().optional().describe('Parent note ID for replies'),
      tagNames: z.array(z.string()).optional().describe('Tag names to attach'),
    },
    async ({ content, parentId, tagNames }) => {
      try {
        const note = await callMcpRpc<Note>('mcp_create_note', {
          p_content: content,
          p_parent_id: parentId || null,
          p_tag_names: tagNames || null,
        })

        return {
          content: [
            {
              type: 'text' as const,
              text: JSON.stringify(
                { id: note.id, displayId: note.display_id, content: note.content, createdAt: note.created_at },
                null,
                2
              ),
            },
          ],
        }
      } catch (err) {
        return {
          content: [{ type: 'text' as const, text: `Error: ${(err as Error).message}` }],
          isError: true,
        }
      }
    }
  )

  server.tool(
    'update_note',
    'Update an existing note',
    {
      noteId: z.string().uuid().describe('The UUID of the note'),
      content: z.string().describe('The new content'),
    },
    async ({ noteId, content }) => {
      try {
        const note = await callMcpRpc<Note>('mcp_update_note', {
          p_note_id: noteId,
          p_content: content,
        })

        return {
          content: [
            {
              type: 'text' as const,
              text: JSON.stringify(
                { id: note.id, displayId: note.display_id, content: note.content, updatedAt: note.updated_at },
                null,
                2
              ),
            },
          ],
        }
      } catch (err) {
        return {
          content: [{ type: 'text' as const, text: `Error: ${(err as Error).message}` }],
          isError: true,
        }
      }
    }
  )

  server.tool(
    'delete_note',
    'Soft-delete a note (move to trash)',
    {
      noteId: z.string().uuid().describe('The UUID of the note'),
    },
    async ({ noteId }) => {
      try {
        await callMcpRpc<SuccessResult>('mcp_delete_note', { p_note_id: noteId })
        return {
          content: [{ type: 'text' as const, text: `Note ${noteId} moved to trash` }],
        }
      } catch (err) {
        return {
          content: [{ type: 'text' as const, text: `Error: ${(err as Error).message}` }],
          isError: true,
        }
      }
    }
  )

  server.tool(
    'archive_note',
    'Archive a note',
    {
      noteId: z.string().uuid().describe('The UUID of the note'),
    },
    async ({ noteId }) => {
      try {
        await callMcpRpc<SuccessResult>('mcp_archive_note', { p_note_id: noteId })
        return {
          content: [{ type: 'text' as const, text: `Note ${noteId} archived` }],
        }
      } catch (err) {
        return {
          content: [{ type: 'text' as const, text: `Error: ${(err as Error).message}` }],
          isError: true,
        }
      }
    }
  )

  // 이슈 생성 자체는 이 서버가 하지 않는다 — 에이전트가 Linear MCP로 만들고,
  // 그 결과 URL만 여기에 적는다. Drop에 Linear 토큰을 두지 않기 위한 선택이다 (BRU-45).
  server.tool(
    'set_note_export',
    'Mark a note as exported to a Linear issue. Create the issue with the Linear MCP first, then record its URL here so the note stops showing up as unprocessed.',
    {
      noteId: z.string().uuid().describe('The UUID of the note'),
      issueUrl: z.string().url().describe('URL of the Linear issue the note became'),
      issueKey: z
        .string()
        .optional()
        .describe('Issue identifier such as BRU-96. Shown as the badge on the note card.'),
    },
    async ({ noteId, issueUrl, issueKey }) => {
      try {
        const result = await callMcpRpc<SuccessResult & { linear_issue_key: string | null }>(
          'mcp_set_note_export',
          { p_note_id: noteId, p_issue_url: issueUrl, p_issue_key: issueKey ?? null }
        )
        return {
          content: [
            {
              type: 'text' as const,
              text: `Note ${noteId} marked as exported to ${result.linear_issue_key ?? issueUrl}`,
            },
          ],
        }
      } catch (err) {
        return {
          content: [{ type: 'text' as const, text: `Error: ${(err as Error).message}` }],
          isError: true,
        }
      }
    }
  )

  server.tool(
    'clear_note_export',
    'Remove the Linear export mark from a note (the issue was deleted, or it was marked by mistake)',
    {
      noteId: z.string().uuid().describe('The UUID of the note'),
    },
    async ({ noteId }) => {
      try {
        await callMcpRpc<SuccessResult>('mcp_clear_note_export', { p_note_id: noteId })
        return {
          content: [{ type: 'text' as const, text: `Export mark cleared on note ${noteId}` }],
        }
      } catch (err) {
        return {
          content: [{ type: 'text' as const, text: `Error: ${(err as Error).message}` }],
          isError: true,
        }
      }
    }
  )
}
