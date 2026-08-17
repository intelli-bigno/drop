import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js'
import { z } from 'zod'
import { callMcpRpc } from '../supabase.js'

// 댓글은 노트가 아니다 (BRU-61). 노트 목록·검색에는 절대 나타나지 않고,
// 오직 노트에 매달린 짧은 응답으로만 존재한다.
interface Comment {
  id: string
  note_id: string
  body: string
  created_at: string
  updated_at: string
}

interface ListCommentsResult {
  comments: Comment[]
  total: number
}

interface AddCommentResult {
  success: boolean
  comment_id: string
  note_id: string
}

interface DeleteCommentResult {
  success: boolean
  comment_id: string
}

function toClient(comment: Comment) {
  return {
    id: comment.id,
    noteId: comment.note_id,
    body: comment.body,
    createdAt: comment.created_at,
    updatedAt: comment.updated_at,
  }
}

export function registerCommentsTools(server: McpServer) {
  server.tool(
    'list_comments',
    'List comments on a note, oldest first',
    {
      noteId: z.string().uuid().describe('The UUID of the note'),
      limit: z.number().min(1).max(200).default(50).describe('Number of comments to return'),
    },
    async ({ noteId, limit }) => {
      try {
        const result = await callMcpRpc<ListCommentsResult>('mcp_list_comments', {
          p_note_id: noteId,
          p_limit: limit,
        })

        return {
          content: [
            {
              type: 'text' as const,
              text: JSON.stringify(
                { comments: result.comments.map(toClient), total: result.total },
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
    'add_comment',
    'Add a comment to a note. Use this instead of creating a child note when responding to an existing note.',
    {
      noteId: z.string().uuid().describe('The UUID of the note to comment on'),
      body: z.string().min(1).describe('Comment text'),
    },
    async ({ noteId, body }) => {
      try {
        const result = await callMcpRpc<AddCommentResult>('mcp_add_comment', {
          p_note_id: noteId,
          p_body: body,
        })

        return {
          content: [
            {
              type: 'text' as const,
              text: JSON.stringify(
                { success: result.success, commentId: result.comment_id, noteId: result.note_id },
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
    'delete_comment',
    'Delete a comment. Comments have no trash — this is permanent.',
    {
      commentId: z.string().uuid().describe('The UUID of the comment'),
    },
    async ({ commentId }) => {
      try {
        const result = await callMcpRpc<DeleteCommentResult>('mcp_delete_comment', {
          p_comment_id: commentId,
        })

        return {
          content: [
            {
              type: 'text' as const,
              text: JSON.stringify(
                { success: result.success, commentId: result.comment_id },
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
