import { getApiKeyForRpc } from './supabase.js'

interface SignedResult {
  path: string
  signedUrl: string
}

interface DeleteResult {
  path: string
  deleted: boolean
}

function getStorageProxyUrl(): string {
  const url = process.env.SUPABASE_URL
  if (!url) {
    throw new Error(
      'SUPABASE_URL must be set.\n' + 'Add it to your .mcp.json env configuration.'
    )
  }
  return `${url}/functions/v1/mcp-storage`
}

async function callStorageProxy<T>(body: Record<string, unknown>): Promise<T> {
  const response = await fetch(getStorageProxyUrl(), {
    method: 'POST',
    headers: {
      'X-Drop-Token': getApiKeyForRpc(),
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  })

  const data = (await response.json().catch(() => null)) as
    | (Record<string, unknown> & { error?: string })
    | null

  if (!response.ok) {
    const message =
      data && typeof data.error === 'string'
        ? data.error
        : `Storage proxy error (HTTP ${response.status})`
    throw new Error(message)
  }

  return data as T
}

export async function uploadViaProxy(
  path: string,
  contentBase64: string,
  contentType: string
): Promise<SignedResult> {
  return callStorageProxy<SignedResult>({
    action: 'upload',
    path,
    contentBase64,
    contentType,
  })
}

export async function signViaProxy(path: string, expiresIn: number): Promise<SignedResult> {
  return callStorageProxy<SignedResult>({ action: 'sign', path, expiresIn })
}

export async function deleteViaProxy(path: string): Promise<DeleteResult> {
  return callStorageProxy<DeleteResult>({ action: 'delete', path })
}
