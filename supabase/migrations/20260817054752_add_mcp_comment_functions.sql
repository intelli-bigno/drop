-- MCP에서 댓글 읽기·쓰기 (BRU-62)
--
-- MCP는 API 키로 인증하므로 RLS를 타지 않는다 — 기존 mcp_* 함수들과 같이
-- SECURITY DEFINER + mcp_validate_key(api_key)로 소유자를 확인하고,
-- 노트 소유권을 매번 다시 확인한다 (mcp_remove_tags_from_note와 같은 방식).
--
-- 이 표면이 있어야 에이전트가 노트에 "댓글"로 답할 수 있다. 지금은 하위 노트로 답해서
-- 피드에 독립 노트가 쌓인다 — 댓글을 별도 테이블로 뺀 이유가 여기에 있다.

-- 노트의 댓글 목록 (오래된 순 — 대화 읽는 순서)
CREATE OR REPLACE FUNCTION mcp_list_comments(
  api_key TEXT,
  p_note_id UUID,
  p_limit INT DEFAULT 50
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  uid UUID;
  v_limit INT := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200);
  result JSON;
BEGIN
  uid := mcp_validate_key(api_key);

  IF NOT EXISTS (SELECT 1 FROM notes WHERE id = p_note_id AND user_id = uid) THEN
    RAISE EXCEPTION 'Note not found';
  END IF;

  SELECT json_build_object(
    'comments', COALESCE(json_agg(row_to_json(c.*) ORDER BY c.created_at), '[]'::json),
    'total', (SELECT COUNT(*) FROM note_comments WHERE note_id = p_note_id)
  ) INTO result
  FROM (
    SELECT id, note_id, body, created_at, updated_at
    FROM note_comments
    WHERE note_id = p_note_id
    ORDER BY created_at
    LIMIT v_limit
  ) c;

  RETURN result;
END;
$$;

-- 댓글 달기
CREATE OR REPLACE FUNCTION mcp_add_comment(
  api_key TEXT,
  p_note_id UUID,
  p_body TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  uid UUID;
  new_id UUID;
BEGIN
  uid := mcp_validate_key(api_key);

  IF NOT EXISTS (SELECT 1 FROM notes WHERE id = p_note_id AND user_id = uid) THEN
    RAISE EXCEPTION 'Note not found';
  END IF;

  IF p_body IS NULL OR btrim(p_body) = '' THEN
    RAISE EXCEPTION 'Comment body is empty';
  END IF;

  INSERT INTO note_comments (note_id, user_id, body)
  VALUES (p_note_id, uid, p_body)
  RETURNING id INTO new_id;

  RETURN json_build_object('success', true, 'comment_id', new_id, 'note_id', p_note_id);
END;
$$;

-- 댓글 삭제 (하드 삭제 — 댓글에는 휴지통이 없다)
CREATE OR REPLACE FUNCTION mcp_delete_comment(
  api_key TEXT,
  p_comment_id UUID
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

  DELETE FROM note_comments WHERE id = p_comment_id AND user_id = uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Comment not found';
  END IF;

  RETURN json_build_object('success', true, 'comment_id', p_comment_id);
END;
$$;

-- 기존 mcp_* 함수와 같은 노출 범위: anon 롤이 API 키로 호출한다.
REVOKE EXECUTE ON FUNCTION mcp_list_comments(TEXT, UUID, INT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION mcp_add_comment(TEXT, UUID, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION mcp_delete_comment(TEXT, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION mcp_list_comments(TEXT, UUID, INT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION mcp_add_comment(TEXT, UUID, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION mcp_delete_comment(TEXT, UUID) TO anon, authenticated;
