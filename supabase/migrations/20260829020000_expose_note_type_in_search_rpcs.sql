-- 검색·태그 조회 RPC에도 노트 타입을 싣는다 (BRU-183)
--
-- BRU-175에서 `mcp_list_notes`·`mcp_get_note` 둘만 고쳤다. 나머지 셋은 `SELECT *`가
-- 아니라 **명시적 좁은 컬럼 목록**을 쓰고 있어 새 컬럼이 응답에 실리지 않는다:
--
--   mcp_get_notes_by_tag / mcp_search_notes / mcp_search_by_date_range
--     → id, display_id, content, created_at, has_link, has_media, has_files
--
-- 왜 문제인가 — drop-loop이 실제로 노트를 훑는 경로가 `mcp_get_notes_by_tag`다.
-- 검색 결과에 타입이 없으면 에이전트가 "이미 할일로 판정된 노트"를 못 알아보고
-- 다시 판정한다. 클라이언트만 고치면 응답에 필드가 없어 undefined가 나간다.
--
-- 본문은 20260810090000(보안 강화)의 것을 그대로 두고 SELECT 목록에 두 컬럼만
-- 더한다 — SECURITY DEFINER·search_path 고정·v_limit 상한을 잃지 않기 위해서다.

CREATE OR REPLACE FUNCTION mcp_get_notes_by_tag(api_key TEXT, p_tag_name TEXT, p_limit INT DEFAULT 50)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  uid UUID;
  tid UUID;
  v_limit INT := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
BEGIN
  uid := mcp_validate_key(api_key);

  SELECT id INTO tid FROM tags WHERE name = p_tag_name AND user_id = uid;
  IF tid IS NULL THEN
    RAISE EXCEPTION 'Tag not found';
  END IF;

  RETURN (
    SELECT json_build_object(
      'tag_name', p_tag_name,
      'notes', COALESCE(json_agg(row_to_json(n.*) ORDER BY n.created_at DESC), '[]'::json)
    )
    FROM (
      SELECT n.id, n.display_id, n.content, n.created_at, n.has_link, n.has_media, n.has_files,
             n.type, n.completed_at
      FROM notes n
      JOIN note_tags nt ON n.id = nt.note_id
      WHERE nt.tag_id = tid AND n.user_id = uid AND n.deleted_at IS NULL
      LIMIT v_limit
    ) n
  );
END;
$$;

CREATE OR REPLACE FUNCTION mcp_search_notes(
  api_key TEXT,
  p_query TEXT,
  p_tag_names TEXT[] DEFAULT NULL,
  p_category TEXT DEFAULT 'all',
  p_limit INT DEFAULT 20
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  uid UUID;
  v_limit INT := LEAST(GREATEST(COALESCE(p_limit, 20), 1), 100);
BEGIN
  uid := mcp_validate_key(api_key);

  RETURN (
    SELECT json_build_object('notes', COALESCE(json_agg(row_to_json(n.*)), '[]'::json))
    FROM (
      SELECT DISTINCT n.id, n.display_id, n.content, n.created_at,
             n.has_link, n.has_media, n.has_files, n.type, n.completed_at
      FROM notes n
      LEFT JOIN note_tags nt ON n.id = nt.note_id
      LEFT JOIN tags t ON nt.tag_id = t.id
      WHERE n.user_id = uid
        AND n.deleted_at IS NULL
        AND n.content ILIKE '%' || p_query || '%'
        AND (p_category = 'all'
             OR (p_category = 'links' AND n.has_link)
             OR (p_category = 'media' AND n.has_media)
             OR (p_category = 'files' AND n.has_files))
        AND (p_tag_names IS NULL OR t.name = ANY(p_tag_names))
      ORDER BY n.created_at DESC
      LIMIT v_limit
    ) n
  );
END;
$$;

CREATE OR REPLACE FUNCTION mcp_search_by_date_range(
  api_key TEXT,
  p_start_date TIMESTAMPTZ,
  p_end_date TIMESTAMPTZ,
  p_limit INT DEFAULT 50
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  uid UUID;
  v_limit INT := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
BEGIN
  uid := mcp_validate_key(api_key);

  RETURN (
    SELECT json_build_object('notes', COALESCE(json_agg(row_to_json(n.*) ORDER BY n.created_at DESC), '[]'::json))
    FROM (
      SELECT id, display_id, content, created_at, has_link, has_media, has_files,
             type, completed_at
      FROM notes
      WHERE user_id = uid
        AND deleted_at IS NULL
        AND created_at >= p_start_date
        AND created_at <= p_end_date
      LIMIT v_limit
    ) n
  );
END;
$$;
