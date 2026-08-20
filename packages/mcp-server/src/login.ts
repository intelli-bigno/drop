#!/usr/bin/env node
/**
 * CLI 로그인 명령
 * 이메일/패스워드 또는 토큰 직접 입력 방식
 */
import 'dotenv/config'
import { createInterface } from 'readline'
import { createClient } from '@supabase/supabase-js'
import { saveRefreshToken, isAuthenticated } from './auth.js'

const SUPABASE_URL = process.env.SUPABASE_URL
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  console.error('❌ Error: SUPABASE_URL and SUPABASE_ANON_KEY must be set.')
  console.error('   Set them in packages/mcp-server/.env file.')
  process.exit(1)
}

// TypeScript narrowing 후 상수로 재할당
const supabaseUrl: string = SUPABASE_URL
const supabaseAnonKey: string = SUPABASE_ANON_KEY

const rl = createInterface({
  input: process.stdin,
  output: process.stdout,
})

function question(prompt: string): Promise<string> {
  return new Promise((resolve) => {
    rl.question(prompt, resolve)
  })
}

async function loginWithEmail() {
  const supabase = createClient(supabaseUrl, supabaseAnonKey)

  const email = await question('Email: ')
  const password = await question('Password: ')

  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  })

  if (error) {
    console.error('Login failed:', error.message)
    return false
  }

  if (data.session?.refresh_token) {
    saveRefreshToken(data.session.refresh_token)
    console.log('\nLogin successful!')
    console.log('User:', data.user?.email)
    console.log('Refresh token saved to .env')
    return true
  }

  console.error('No session received')
  return false
}

async function loginWithToken() {
  console.log('\nTo get your refresh token:')
  console.log('1. Open DROP Desktop app')
  console.log('2. Open DevTools (Cmd+Option+I)')
  console.log('3. Run in Console: (await supabase.auth.getSession()).data.session?.refresh_token')
  console.log('')

  const token = await question('Paste refresh token: ')

  if (!token.trim()) {
    console.error('No token provided')
    return false
  }

  // 토큰 유효성 검증
  const supabase = createClient(supabaseUrl, supabaseAnonKey)
  const { data, error } = await supabase.auth.refreshSession({
    refresh_token: token.trim(),
  })

  if (error) {
    console.error('Invalid token:', error.message)
    return false
  }

  if (data.session?.refresh_token) {
    saveRefreshToken(data.session.refresh_token)
    console.log('\nToken saved successfully!')
    console.log('User:', data.user?.email)
    return true
  }

  console.error('Failed to validate token')
  return false
}

async function main() {
  console.log('DROP MCP Server - Authentication')
  console.log('=================================')
  console.log(`Supabase URL: ${SUPABASE_URL}`)
  console.log('')

  if (isAuthenticated()) {
    const answer = await question('Already authenticated. Re-authenticate? (y/N): ')
    if (answer.toLowerCase() !== 'y') {
      console.log('Keeping existing authentication.')
      rl.close()
      process.exit(0)
    }
  }

  console.log('\nChoose authentication method:')
  console.log('1. Email/Password')
  console.log('2. Paste refresh token from Desktop app')
  console.log('')

  const choice = await question('Choice (1 or 2): ')

  let success = false
  if (choice === '1') {
    success = await loginWithEmail()
  } else if (choice === '2') {
    success = await loginWithToken()
  } else {
    console.error('Invalid choice')
  }

  rl.close()
  process.exit(success ? 0 : 1)
}

main().catch((err) => {
  console.error('Error:', err)
  rl.close()
  process.exit(1)
})
