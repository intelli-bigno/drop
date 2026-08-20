#!/usr/bin/env node
/**
 * DROP Notes MCP Server
 * AI가 DROP 노트에 접근할 수 있는 MCP 서버
 *
 * 필수 환경 변수:
 *   - DROP_TOKEN: MCP API 키 (DROP 앱 → 프로필 → Copy MCP Token)
 *   - SUPABASE_URL: Supabase 프로젝트 URL
 *   - SUPABASE_ANON_KEY: Supabase anon key
 */
import 'dotenv/config'
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js'
import { createServer } from './server.js'

async function main() {
  const server = createServer()
  const transport = new StdioServerTransport()

  await server.connect(transport)
  console.error('DROP MCP Server started')
}

main().catch((err) => {
  console.error('Server error:', err)
  process.exit(1)
})
