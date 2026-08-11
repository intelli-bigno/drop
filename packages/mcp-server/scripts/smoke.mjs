#!/usr/bin/env node
// MCP 서버 스모크 테스트 — stdio로 실제 MCP 프로토콜을 태워 인증과 도구를 확인한다.
//
//   DROP_TOKEN=drop_xxx SUPABASE_URL=... SUPABASE_ANON_KEY=... node scripts/smoke.mjs
//
// 로컬 스택 기본값이 들어 있어, `supabase start` 상태라면 DROP_TOKEN만 주면 된다.
// 토큰은 앱(프로필 → Copy MCP Token) 또는 로컬 DB에서 발급한다.
//
// 노트를 만들고 지우므로 실제 계정이 아닌 테스트 계정에서 돌릴 것.

import { spawn } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'

const LOCAL_ANON =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0'

const TOKEN = process.env.DROP_TOKEN
if (!TOKEN) {
  console.error('DROP_TOKEN이 필요하다. 앱 → 프로필 → Copy MCP Token')
  process.exit(1)
}

const serverDir = resolve(dirname(fileURLToPath(import.meta.url)), '..')

const child = spawn('node', ['dist/index.js'], {
  cwd: serverDir,
  env: {
    ...process.env,
    DROP_TOKEN: TOKEN,
    SUPABASE_URL: process.env.SUPABASE_URL ?? 'http://127.0.0.1:58321',
    SUPABASE_ANON_KEY: process.env.SUPABASE_ANON_KEY ?? LOCAL_ANON,
  },
  stdio: ['pipe', 'pipe', 'pipe'],
})

let buffer = ''
const pending = new Map()
let nextId = 1

child.stdout.on('data', (chunk) => {
  buffer += chunk.toString()
  let idx
  while ((idx = buffer.indexOf('\n')) >= 0) {
    const line = buffer.slice(0, idx).trim()
    buffer = buffer.slice(idx + 1)
    if (!line) continue
    let msg
    try {
      msg = JSON.parse(line)
    } catch {
      continue
    }
    if (msg.id && pending.has(msg.id)) {
      pending.get(msg.id)(msg)
      pending.delete(msg.id)
    }
  }
})

const stderrLines = []
child.stderr.on('data', (c) => stderrLines.push(c.toString().trim()))

function send(method, params) {
  const id = nextId++
  return new Promise((resolvePromise, reject) => {
    pending.set(id, resolvePromise)
    child.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n')
    setTimeout(() => reject(new Error(`timeout: ${method}`)), 15000)
  })
}

const results = []
function check(label, passed, detail = '') {
  results.push(passed)
  const mark = passed ? '✅' : '❌'
  console.log(`${mark} ${label}${detail ? ` — ${detail}` : ''}`)
}

const textOf = (res) =>
  res?.result?.content?.map((c) => c.text).join('\n') ?? JSON.stringify(res?.error ?? res)
const oneLine = (s, n = 90) => s.slice(0, n).replace(/\s+/g, ' ')

try {
  const init = await send('initialize', {
    protocolVersion: '2024-11-05',
    capabilities: {},
    clientInfo: { name: 'drop-mcp-smoke', version: '1.0.0' },
  })
  check('initialize', !!init.result, init.result?.serverInfo?.name ?? '')
  child.stdin.write(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }) + '\n')

  const tools = await send('tools/list', {})
  const names = (tools.result?.tools ?? []).map((t) => t.name)
  check('tools/list', names.length > 0, `${names.length}개`)

  const list = await send('tools/call', { name: 'list_notes', arguments: { limit: 5 } })
  check('인증 + list_notes', !list.result?.isError, oneLine(textOf(list)))

  const created = await send('tools/call', {
    name: 'create_note',
    arguments: { content: 'drop-mcp smoke test', tagNames: ['smoke-test'] },
  })
  const noteId = textOf(created).match(
    /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/
  )?.[0]
  // notes.source='mcp'가 CHECK 제약에 없어 오래 깨져 있던 자리 — 회귀 감시 지점이다.
  check('create_note', !!noteId, oneLine(textOf(created)))

  if (noteId) {
    const updated = await send('tools/call', {
      name: 'update_note',
      arguments: { noteId, content: 'drop-mcp smoke test (updated)' },
    })
    check('update_note', !updated.result?.isError, oneLine(textOf(updated), 60))

    const got = await send('tools/call', { name: 'get_note', arguments: { noteId } })
    check('get_note', textOf(got).includes('updated'), oneLine(textOf(got), 60))

    const tags = await send('tools/call', { name: 'list_tags', arguments: {} })
    check('list_tags', textOf(tags).includes('smoke-test'), oneLine(textOf(tags), 60))

    const byTag = await send('tools/call', {
      name: 'get_notes_by_tag',
      arguments: { tagName: 'smoke-test' },
    })
    check('get_notes_by_tag', !byTag.result?.isError, oneLine(textOf(byTag), 60))

    const search = await send('tools/call', {
      name: 'search_notes',
      arguments: { query: 'smoke' },
    })
    check('search_notes', !search.result?.isError, oneLine(textOf(search), 60))

    const atts = await send('tools/call', { name: 'list_attachments', arguments: { noteId } })
    check('list_attachments', !atts.result?.isError, oneLine(textOf(atts), 60))

    const del = await send('tools/call', { name: 'delete_note', arguments: { noteId } })
    check('delete_note (정리)', !del.result?.isError, oneLine(textOf(del), 60))
  }

  const passed = results.filter(Boolean).length
  console.log(`\n${passed}/${results.length} 통과`)
  if (passed !== results.length) {
    if (stderrLines.length) console.log('\n[stderr]\n' + stderrLines.join('\n').slice(0, 600))
    process.exitCode = 1
  }
} catch (err) {
  console.error('실패:', err.message)
  if (stderrLines.length) console.error('[stderr]\n' + stderrLines.join('\n').slice(0, 800))
  process.exitCode = 1
} finally {
  child.kill()
}
