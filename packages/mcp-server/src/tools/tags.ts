import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js'
import { z } from 'zod'
import { callMcpRpc } from '../supabase.js'
import { toTodoFields, type NoteRow } from '../note-shape.js'

interface Tag {
  id: string
  name: string
  note_count: number
}

interface ListTagsResult {
  tags: Tag[]
}

interface GetNotesByTagResult {
  tag_name: string
  notes: NoteRow[]
}

interface TagOperationResult {
  success: boolean
  added_tags?: string[]
  removed_tags?: string[]
}

export function registerTagsTools(server: McpServer) {
  server.tool(
    'list_tags',
    'List all tags with note counts',
    {
      limit: z.number().min(1).max(100).default(50).describe('Number of tags to return'),
    },
    async ({ limit }) => {
      try {
        const result = await callMcpRpc<ListTagsResult>('mcp_list_tags', { p_limit: limit })

        const tags = result.tags.map((tag) => ({
          id: tag.id,
          name: tag.name,
          noteCount: tag.note_count,
        }))

        return {
          content: [
            {
              type: 'text' as const,
              text: JSON.stringify({ tags, total: tags.length }, null, 2),
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
    'get_notes_by_tag',
    'Get all notes with a specific tag',
    {
      tagName: z.string().describe('The tag name'),
      limit: z.number().min(1).max(100).default(50).describe('Number of notes to return'),
    },
    async ({ tagName, limit }) => {
      try {
        const result = await callMcpRpc<GetNotesByTagResult>('mcp_get_notes_by_tag', {
          p_tag_name: tagName,
          p_limit: limit,
        })

        const notes = result.notes.map((note) => ({
          id: note.id,
          displayId: note.display_id,
          content: note.content,
          createdAt: note.created_at,
          hasLink: note.has_link,
          hasMedia: note.has_media,
          hasFiles: note.has_files,
          ...toTodoFields(note),
        }))

        return {
          content: [
            {
              type: 'text' as const,
              text: JSON.stringify(
                { tagName: result.tag_name, notes, total: notes.length },
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
    'add_tags_to_note',
    'Add tags to a note',
    {
      noteId: z.string().uuid().describe('The UUID of the note'),
      tagNames: z.array(z.string()).describe('Tag names to add'),
    },
    async ({ noteId, tagNames }) => {
      try {
        const result = await callMcpRpc<TagOperationResult>('mcp_add_tags_to_note', {
          p_note_id: noteId,
          p_tag_names: tagNames,
        })

        return {
          content: [
            {
              type: 'text' as const,
              text: `Added tags to note ${noteId}: ${result.added_tags?.join(', ') || 'none'}`,
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
    'remove_tags_from_note',
    'Remove tags from a note',
    {
      noteId: z.string().uuid().describe('The UUID of the note'),
      tagNames: z.array(z.string()).describe('Tag names to remove'),
    },
    async ({ noteId, tagNames }) => {
      try {
        const result = await callMcpRpc<TagOperationResult>('mcp_remove_tags_from_note', {
          p_note_id: noteId,
          p_tag_names: tagNames,
        })

        return {
          content: [
            {
              type: 'text' as const,
              text: `Removed tags from note ${noteId}: ${result.removed_tags?.join(', ') || 'none'}`,
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
}
