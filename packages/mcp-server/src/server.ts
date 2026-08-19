import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js'
import { registerNotesTools } from './tools/notes.js'
import { registerSearchTools } from './tools/search.js'
import { registerTagsTools } from './tools/tags.js'
import { registerAttachmentsTools } from './tools/attachments.js'
import { registerCommentsTools } from './tools/comments.js'

/**
 * Braindump Notes MCP 서버 생성
 */
export function createServer(): McpServer {
  const server = new McpServer({
    name: 'drop-notes',
    version: '0.0.1',
  })

  // Tools 등록
  registerNotesTools(server)
  registerSearchTools(server)
  registerTagsTools(server)
  registerAttachmentsTools(server)
  registerCommentsTools(server)

  return server
}
