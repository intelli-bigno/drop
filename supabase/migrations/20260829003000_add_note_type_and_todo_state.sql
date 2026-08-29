-- 노트 타입과 할일 완료 상태 (BRU-175)
--
-- 노트에는 **그 자체가 할일인 것**과 **생각·메모를 정리하는 것**이 섞여 있는데,
-- 지금까지 그걸 가르는 자리가 없어 태그로 흉내내 왔다. 두 가지가 실측으로 깨졌다.
--
--  (1) 어휘가 두 갈래다 — 에이전트는 `agent:task`(49건), 사람은 `할일`(2건).
--      태그는 전역 UNIQUE 자유 문자열이라 오타 중복도 생긴다(`콘텐츠` 27 / `컨텐츠` 4).
--  (2) 분류 축이 Inbox 축과 충돌한다 — Inbox의 정의가 "태그가 하나도 없는 노트"라서,
--      에이전트가 `agent:task`를 붙이는 순간 그 노트가 Inbox에서 사라진다.
--      "할일로 분류됨"과 "정리 끝남"이 같은 신호가 돼 버렸다.
--
-- 왜 컬럼인가 — BRU-61(댓글)에서 `notes.kind`를 거절한 이유는 "댓글은 노트가 아니라서
-- 노트를 읽는 모든 경로에 *제외* 조건을 붙여야 한다"였다. 할일과 일반 노트는 **둘 다
-- 노트다.** 제외할 것이 없고 필터 축이 하나 느는 것뿐이다 — `priority`·`has_link`·
-- `is_pinned`이 이미 그 자리에 있는 컬럼이다.

ALTER TABLE notes
  ADD COLUMN type TEXT NOT NULL DEFAULT 'note' CHECK (type IN ('note', 'todo')),
  ADD COLUMN completed_at TIMESTAMPTZ;

COMMENT ON COLUMN notes.type IS
  'BRU-175: 노트의 종류. note=일반(생각·메모·레퍼런스), todo=그 자체가 할일. 기본 note.';
COMMENT ON COLUMN notes.completed_at IS
  'BRU-175: 할일을 끝낸 시각. NULL이면 미완료. type=todo일 때만 채워질 수 있다.';

-- 어중간한 행을 막는다 (notes_linear_export_consistent와 같은 방식).
-- 일반 노트로 되돌리면 완료 시각도 함께 지워야 한다 — 그러지 않으면 화면이
-- 조용히 잘못 그려진다.
ALTER TABLE notes ADD CONSTRAINT notes_todo_state_consistent CHECK (
  completed_at IS NULL OR type = 'todo'
);

-- 새로 생기는 접근 패턴은 "미완료 할일을 긴급도 순으로". 전체 노트에 비하면
-- 소수이므로 부분 인덱스로 잡는다 (notes_linear_exported_idx와 같은 판단).
CREATE INDEX notes_open_todo_idx
  ON notes (user_id, priority DESC, created_at DESC)
  WHERE type = 'todo' AND completed_at IS NULL;

-- ============================================================
-- 백필 — `agent:task`가 붙은 노트만 할일로 옮긴다
-- ============================================================
--
-- 완료 시각은 **채우지 않는다.** `agent:done`(95건)을 완료로 쓰려 했으나 실측해 보니
-- 그 태그의 뜻은 "할일을 끝냈다"가 아니라 "drop-loop이 이 캡처의 트리아지를 마쳤다"였다
-- (#101 "Ai-Native 시대에 CEO의 시스템과 업무 처리 방식", #100 "직접 하지 마라!" 같은
-- 생각 노트에도 붙어 있다). `agent:linear`도 이슈가 열려 있을 수 있어 완료가 아니다.
-- 신뢰할 출처가 없으므로 추정해서 채우는 대신 전부 미완료로 둔다.
--
-- updated_at을 건드리지 않는다 — 분류를 옮긴 것은 노트를 고친 것이 아니다.
-- (같은 이유로 note_revisions 스냅샷 트리거도 content를 안 건드리므로 돌지 않는다.)
ALTER TABLE notes DISABLE TRIGGER notes_updated_at;

UPDATE notes n
SET type = 'todo'
FROM note_tags nt
JOIN tags t ON t.id = nt.tag_id
WHERE nt.note_id = n.id
  AND t.name = 'agent:task'
  AND n.type = 'note';

ALTER TABLE notes ENABLE TRIGGER notes_updated_at;

-- RLS: notes에 이미 켜져 있고 정책은 user_id 기준 행 단위다. 컬럼이 늘어도 그대로
-- 적용된다. 컬럼 단위 GRANT를 쓰지 않으므로 explicit_table_grants의 테이블 권한이 덮는다.

-- ============================================================
-- MCP 표면 — 에이전트가 타입과 완료를 읽고 쓴다
-- ============================================================
--
-- 읽기(list·get)에 두 필드를 더하고, 쓰기는 기존 함수에 기본값 인자로 붙인다.
-- 기본값을 준 덕에 인자를 안 넘기는 기존 호출은 그대로 동작한다.

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
AS $$
DECLARE
  uid UUID;
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
           type, completed_at,
           created_at, updated_at, deleted_at, archived_at
    FROM notes
    WHERE user_id = uid
      AND (p_include_deleted OR deleted_at IS NULL)
      AND (p_include_archived OR archived_at IS NULL)
    ORDER BY created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) n;

  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION mcp_get_note(api_key TEXT, p_note_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
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
    'type', n.type,
    'completed_at', n.completed_at,
    'created_at', n.created_at,
    'updated_at', n.updated_at,
    'deleted_at', n.deleted_at,
    'archived_at', n.archived_at,
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

-- 생성 시 타입을 정할 수 있게 한다. 기본은 'note' — 에이전트가 명시하지 않으면
-- 할일이 아니다. (drop-loop이 `agent:task` 대신 이걸 쓰게 된다.)
--
-- 인자가 하나 늘었으므로 CREATE OR REPLACE로는 덮이지 않는다 — 4인자 구버전이 그대로
-- 남아 오버로드가 되고, 4개만 넘긴 호출이 "function is not unique"로 죽는다.
-- 반드시 먼저 지운다.
DROP FUNCTION IF EXISTS mcp_create_note(TEXT, TEXT, UUID, TEXT[]);

CREATE FUNCTION mcp_create_note(
  api_key TEXT,
  p_content TEXT,
  p_parent_id UUID DEFAULT NULL,
  p_tag_names TEXT[] DEFAULT NULL,
  p_type TEXT DEFAULT 'note'
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  uid UUID;
  new_note_id UUID;
  tag_name TEXT;
  tag_id UUID;
BEGIN
  uid := mcp_validate_key(api_key);

  IF p_type NOT IN ('note', 'todo') THEN
    RAISE EXCEPTION 'Invalid note type: %', p_type;
  END IF;

  INSERT INTO notes (content, parent_id, source, user_id, type)
  VALUES (p_content, p_parent_id, 'mcp', uid, p_type)
  RETURNING id INTO new_note_id;

  IF p_tag_names IS NOT NULL THEN
    FOREACH tag_name IN ARRAY p_tag_names LOOP
      INSERT INTO tags (name, user_id) VALUES (tag_name, uid)
      ON CONFLICT (name, user_id) DO UPDATE SET name = EXCLUDED.name
      RETURNING id INTO tag_id;

      INSERT INTO note_tags (note_id, tag_id) VALUES (new_note_id, tag_id)
      ON CONFLICT DO NOTHING;
    END LOOP;
  END IF;

  RETURN mcp_get_note(api_key, new_note_id);
END;
$$;

-- 타입 전환과 완료 토글. content를 건드리지 않으므로 note_revisions 스냅샷이 남지
-- 않는다 — 분류·상태를 바꾼 것은 본문을 고친 것이 아니다.
--
-- 일반 노트로 되돌릴 때 완료 시각을 함께 지운다. CHECK 제약이 막아 주기는 하지만,
-- 예외를 던지는 것보다 "할일이 아니게 되면 완료도 아니다"로 흘려보내는 편이 낫다.
CREATE OR REPLACE FUNCTION mcp_set_note_type(
  api_key TEXT,
  p_note_id UUID,
  p_type TEXT
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

  IF p_type NOT IN ('note', 'todo') THEN
    RAISE EXCEPTION 'Invalid note type: %', p_type;
  END IF;

  UPDATE notes
  SET type = p_type,
      completed_at = CASE WHEN p_type = 'todo' THEN completed_at ELSE NULL END
  WHERE id = p_note_id AND user_id = uid;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Note not found';
  END IF;

  RETURN mcp_get_note(api_key, p_note_id);
END;
$$;

-- 완료 표시·해제. 할일이 아닌 노트에는 거부한다 — 조용히 타입을 바꿔 주면
-- "완료했더니 노트 종류가 변했다"가 된다.
CREATE OR REPLACE FUNCTION mcp_set_note_completed(
  api_key TEXT,
  p_note_id UUID,
  p_completed BOOLEAN DEFAULT true
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  uid UUID;
  note_type TEXT;
BEGIN
  uid := mcp_validate_key(api_key);

  SELECT type INTO note_type FROM notes WHERE id = p_note_id AND user_id = uid;

  IF note_type IS NULL THEN
    RAISE EXCEPTION 'Note not found';
  END IF;

  IF note_type <> 'todo' THEN
    RAISE EXCEPTION 'Not a todo note: %', p_note_id;
  END IF;

  UPDATE notes
  SET completed_at = CASE WHEN p_completed THEN now() ELSE NULL END
  WHERE id = p_note_id AND user_id = uid;

  RETURN mcp_get_note(api_key, p_note_id);
END;
$$;

-- 기존 mcp_* 함수와 같은 노출 범위: anon 롤이 API 키로 호출한다.
REVOKE EXECUTE ON FUNCTION mcp_set_note_type(TEXT, UUID, TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION mcp_set_note_completed(TEXT, UUID, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION mcp_set_note_type(TEXT, UUID, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION mcp_set_note_completed(TEXT, UUID, BOOLEAN) TO anon, authenticated;
REVOKE EXECUTE ON FUNCTION mcp_create_note(TEXT, TEXT, UUID, TEXT[], TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION mcp_create_note(TEXT, TEXT, UUID, TEXT[], TEXT) TO anon, authenticated;
