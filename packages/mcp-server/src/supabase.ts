import { createClient, SupabaseClient } from '@supabase/supabase-js'

const SUPABASE_URL = process.env.SUPABASE_URL
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY

const API_KEY = process.env.DROP_TOKEN

function getSupabaseConfig(): { url: string; anonKey: string } {
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
    throw new Error(
      'SUPABASE_URL and SUPABASE_ANON_KEY must be set.\n' +
        'Add them to your .mcp.json env configuration.'
    )
  }
  return { url: SUPABASE_URL, anonKey: SUPABASE_ANON_KEY }
}

const USER_ID_CACHE_TTL_MS = 5 * 60 * 1000 // 5 minutes

let supabaseInstance: SupabaseClient | null = null
let validatedUserId: string | null = null
let validatedAt = 0

function getApiKey(): string {
  if (!API_KEY) {
    throw new Error(
      'DROP_TOKEN not set.\n' +
        '1. Braindump 앱 → 프로필 → Copy MCP Token\n' +
        '2. .mcp.json의 env에 DROP_TOKEN 추가'
    )
  }
  return API_KEY
}

export function getSupabaseClient(): SupabaseClient {
  if (!supabaseInstance) {
    const { url, anonKey } = getSupabaseConfig()
    supabaseInstance = createClient(url, anonKey)
  }
  return supabaseInstance
}

export async function validateApiKey(): Promise<string> {
  if (validatedUserId && Date.now() - validatedAt < USER_ID_CACHE_TTL_MS) {
    return validatedUserId
  }

  const apiKey = getApiKey()
  const supabase = getSupabaseClient()

  const { data, error } = await supabase.rpc('get_user_id_by_mcp_key', {
    api_key: apiKey,
  })

  if (error || !data) {
    throw new Error(
      'Invalid API key.\n' + 'Braindump 앱 → 프로필 → Copy MCP Token에서 새 키를 복사하세요.'
    )
  }

  validatedUserId = data as string
  validatedAt = Date.now()
  return validatedUserId
}

export function getApiKeyForRpc(): string {
  return getApiKey()
}

export async function getUserId(): Promise<string> {
  return validateApiKey()
}

type RpcParams = Record<string, unknown>

export async function callMcpRpc<T>(functionName: string, params: RpcParams = {}): Promise<T> {
  const apiKey = getApiKey()
  const supabase = getSupabaseClient()

  const { data, error } = await supabase.rpc(functionName, {
    api_key: apiKey,
    ...params,
  })

  if (error) {
    throw new Error(error.message)
  }

  return data as T
}
