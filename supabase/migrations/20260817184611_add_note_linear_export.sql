-- 노트의 Linear 반출 표시 (BRU-45)
--
-- 덤프한 노트가 Linear 이슈로 나간 뒤에도 Drop 안에서는 그 사실을 알 수 없어
-- 같은 노트를 두 번 처리하게 된다. 어디로 갔는지를 노트 자체에 적어 둔다.
--
-- 태그(`linear`)로 대신하지 않는 이유: 이슈마다 태그를 만들면(BRU-96식) 태그가 폭발한다.
-- 매핑은 URL 필드가 담당하고, 태그는 분류(Inbox 탈출)에만 쓴다.
--
-- 이슈 **생성**은 앱이 하지 않는다 — 에이전트가 Linear MCP로 만들고, 그 결과를
-- 아래 mcp_set_note_export로 적어 넣는다. 앱에 Linear 토큰을 두지 않기 위한 선택이다.

ALTER TABLE notes
  ADD COLUMN linear_issue_url TEXT,
  ADD COLUMN linear_issue_key TEXT,
  ADD COLUMN linear_exported_at TIMESTAMPTZ;

COMMENT ON COLUMN notes.linear_issue_url IS '반출된 Linear 이슈 URL. NULL이면 반출되지 않은 노트다.';
COMMENT ON COLUMN notes.linear_issue_key IS '이슈 식별자(예: BRU-96). 카드 뱃지에 그대로 쓴다.';
COMMENT ON COLUMN notes.linear_exported_at IS '반출 시각. URL이 있으면 반드시 함께 있다.';

-- URL 없이 키만 남거나, 시각 없이 URL만 남는 어중간한 행을 막는다.
-- 뱃지는 "URL이 있다"로 판정하므로 이 둘이 어긋나면 화면이 조용히 잘못 그려진다.
ALTER TABLE notes ADD CONSTRAINT notes_linear_export_consistent CHECK (
  (linear_issue_url IS NULL AND linear_issue_key IS NULL AND linear_exported_at IS NULL)
  OR (linear_issue_url IS NOT NULL AND linear_exported_at IS NOT NULL)
);

-- 기본 목록은 "반출되지 않은 노트"를 훨씬 자주 훑는다. 부분 인덱스로 반출분만 따로 잡는다.
CREATE INDEX notes_linear_exported_idx
  ON notes (user_id, linear_exported_at DESC)
  WHERE linear_exported_at IS NOT NULL;

-- RLS: notes에 이미 켜져 있고 정책은 user_id 기준 행 단위다. 컬럼이 늘어도 그대로 적용된다.
-- (컬럼 단위 GRANT를 쓰지 않으므로 20260811000000_explicit_table_grants.sql의 테이블 권한이 그대로 덮는다.)

-- ============================================================
-- MCP 표면 — 에이전트가 반출 사실을 적고 지운다
-- ============================================================

-- 반출 표시. 이미 반출된 노트를 다시 부르면 덮어쓴다(이슈를 옮긴 경우).
CREATE OR REPLACE FUNCTION mcp_set_note_export(
  api_key TEXT,
  p_note_id UUID,
  p_issue_url TEXT,
  p_issue_key TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  uid UUID;
BEGIN
  uid := mcp_validate_key(api_key);

  IF p_issue_url IS NULL OR btrim(p_issue_url) = '' THEN
    RAISE EXCEPTION 'Issue URL is empty';
  END IF;

  UPDATE notes
  SET linear_issue_url = btrim(p_issue_url),
      linear_issue_key = NULLIF(btrim(COALESCE(p_issue_key, '')), ''),
      linear_exported_at = now(),
      updated_at = now()
  WHERE id = p_note_id AND user_id = uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Note not found';
  END IF;

  RETURN json_build_object(
    'success', true,
    'note_id', p_note_id,
    'linear_issue_url', btrim(p_issue_url),
    'linear_issue_key', NULLIF(btrim(COALESCE(p_issue_key, '')), '')
  );
END;
$$;

-- 되돌리기. 잘못 반출했거나 이슈를 지운 경우 표시를 걷어낸다.
CREATE OR REPLACE FUNCTION mcp_clear_note_export(api_key TEXT, p_note_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  uid UUID;
BEGIN
  uid := mcp_validate_key(api_key);

  UPDATE notes
  SET linear_issue_url = NULL,
      linear_issue_key = NULL,
      linear_exported_at = NULL,
      updated_at = now()
  WHERE id = p_note_id AND user_id = uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Note not found';
  END IF;

  RETURN json_build_object('success', true, 'note_id', p_note_id);
END;
$$;

-- 읽는 쪽에도 반출 정보를 실어 준다. 없으면 에이전트가 같은 노트를 두 번 반출한다.
CREATE OR REPLACE FUNCTION mcp_list_notes(
  api_key TEXT,
  p_limit INT DEFAULT 20,
  p_offset INT DEFAULT 0,
  p_include_deleted BOOLEAN DEFAULT false,
  p_include_archived BOOLEAN DEFAULT false
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  uid UUID;
  v_limit INT := LEAST(GREATEST(COALESCE(p_limit, 20), 1), 100);
  v_offset INT := GREATEST(COALESCE(p_offset, 0), 0);
  result JSON;
BEGIN
  uid := mcp_validate_key(api_key);

  SELECT json_build_object(
    'notes', COALESCE(json_agg(row_to_json(n.*) ORDER BY n.created_at DESC), '[]'::json),
    'total', (SELECT COUNT(*) FROM notes
              WHERE user_id = uid
              AND (p_include_deleted OR deleted_at IS NULL)
              AND (p_include_archived OR archived_at IS NULL))
  ) INTO result
  FROM (
    SELECT id, display_id, content, source, parent_id, is_locked, has_link, has_media, has_files,
           created_at, updated_at, deleted_at, archived_at,
           linear_issue_url, linear_issue_key, linear_exported_at
    FROM notes
    WHERE user_id = uid
      AND (p_include_deleted OR deleted_at IS NULL)
      AND (p_include_archived OR archived_at IS NULL)
    ORDER BY created_at DESC
    LIMIT v_limit OFFSET v_offset
  ) n;

  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION mcp_get_note(api_key TEXT, p_note_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  uid UUID;
  result JSON;
BEGIN
  uid := mcp_validate_key(api_key);

  SELECT json_build_object(
    'id', n.id,
    'display_id', n.display_id,
    'content', n.content,
    'source', n.source,
    'parent_id', n.parent_id,
    'is_locked', n.is_locked,
    'has_link', n.has_link,
    'has_media', n.has_media,
    'has_files', n.has_files,
    'created_at', n.created_at,
    'updated_at', n.updated_at,
    'deleted_at', n.deleted_at,
    'archived_at', n.archived_at,
    'linear_issue_url', n.linear_issue_url,
    'linear_issue_key', n.linear_issue_key,
    'linear_exported_at', n.linear_exported_at,
    'tags', COALESCE((
      SELECT json_agg(json_build_object('id', t.id, 'name', t.name))
      FROM note_tags nt JOIN tags t ON nt.tag_id = t.id
      WHERE nt.note_id = n.id
    ), '[]'::json),
    'attachments', COALESCE((
      SELECT json_agg(json_build_object(
        'id', a.id, 'type', a.type, 'filename', a.filename,
        'mime_type', a.mime_type, 'size', a.size, 'storage_path', a.storage_path
      ))
      FROM attachments a WHERE a.note_id = n.id
    ), '[]'::json)
  ) INTO result
  FROM notes n
  WHERE n.id = p_note_id AND n.user_id = uid;

  IF result IS NULL THEN
    RAISE EXCEPTION 'Note not found';
  END IF;

  RETURN result;
END;
$$;

-- 기존 mcp_* 함수와 같은 노출 범위: anon 롤이 API 키로 호출한다.
REVOKE EXECUTE ON FUNCTION mcp_set_note_export(TEXT, UUID, TEXT, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION mcp_clear_note_export(TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION mcp_set_note_export(TEXT, UUID, TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION mcp_clear_note_export(TEXT, UUID) TO anon, authenticated;
