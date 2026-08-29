import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js'
import { z } from 'zod'
import { callMcpRpc } from '../supabase.js'
import { toTodoFields, type NoteRow } from '../note-shape.js'

interface SearchResult {
  notes: NoteRow[]
}

export function registerSearchTools(server: McpServer) {
  server.tool(
    'search_notes',
    'Search notes by text content',
    {
      query: z.string().describe('Search query'),
      limit: z.number().min(1).max(50).default(20).describe('Number of results'),
      category: z
        .enum(['all', 'links', 'media', 'files'])
        .default('all')
        .describe('Filter by category'),
      tagNames: z.array(z.string()).optional().describe('Filter by tag names'),
    },
    async ({ query, limit, category, tagNames }) => {
      try {
        const result = await callMcpRpc<SearchResult>('mcp_search_notes', {
          p_query: query,
          p_tag_names: tagNames || null,
          p_category: category,
          p_limit: limit,
        })

        const queryLower = query.toLowerCase()
        const notes = result.notes.map((note) => {
          const contentLower = note.content.toLowerCase()
          const matchIndex = contentLower.indexOf(queryLower)

          let matchedText = ''
          if (matchIndex >= 0) {
            const start = Math.max(0, matchIndex - 50)
            const end = Math.min(note.content.length, matchIndex + query.length + 50)
            matchedText =
              (start > 0 ? '...' : '') +
              note.content.slice(start, end) +
              (end < note.content.length ? '...' : '')
          }

          return {
            id: note.id,
            displayId: note.display_id,
            content: note.content,
            createdAt: note.created_at,
            ...toTodoFields(note),
            matchedText,
          }
        })

        return {
          content: [
            {
              type: 'text' as const,
              text: JSON.stringify({ query, notes, total: notes.length }, null, 2),
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
    'search_by_date_range',
    'Search notes within a date range',
    {
      startDate: z.string().describe('Start date (ISO 8601 format, e.g., 2024-01-01)'),
      endDate: z.string().describe('End date (ISO 8601 format)'),
      limit: z.number().min(1).max(100).default(50).describe('Number of results'),
    },
    async ({ startDate, endDate, limit }) => {
      try {
        const toUtcStart = (dateStr: string): string => {
          if (dateStr.includes('T') || dateStr.includes('Z')) {
            return dateStr
          }
          const date = new Date(dateStr + 'T00:00:00+09:00')
          return date.toISOString()
        }

        const toUtcEnd = (dateStr: string): string => {
          if (dateStr.includes('T') || dateStr.includes('Z')) {
            return dateStr
          }
          const date = new Date(dateStr + 'T23:59:59.999+09:00')
          return date.toISOString()
        }

        const result = await callMcpRpc<SearchResult>('mcp_search_by_date_range', {
          p_start_date: toUtcStart(startDate),
          p_end_date: toUtcEnd(endDate),
          p_limit: limit,
        })

        const toKst = (utcStr: string): string => {
          const date = new Date(utcStr)
          return new Date(date.getTime() + 9 * 60 * 60 * 1000).toISOString().replace('Z', '+09:00')
        }

        const notesWithKst = result.notes.map((note) => ({
          id: note.id,
          displayId: note.display_id,
          content: note.content,
          createdAt: note.created_at,
          createdAtKst: toKst(note.created_at),
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
                {
                  dateRange: { start: startDate, end: endDate, timezone: 'KST' },
                  notes: notesWithKst,
                  total: notesWithKst.length,
                },
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
}
