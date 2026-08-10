-- Security hardening (2026-08-10 review)
-- 1) anon에게 열려 있던 user_profiles / storage 정책 제거 (키·PIN 해시 유출 + 크로스테넌트 접근 차단)
-- 2) MCP API 키를 평문 저장 → sha256 해시 저장으로 전환, 키 포맷 강화(drop_ + 32자)
-- 3) SECURITY DEFINER 함수 전체 search_path 고정
-- 4) mcp_remove_tags_from_note 소유권 체크 추가
-- 5) mcp_* 목록/검색 함수 p_limit/p_offset SQL단 클램프
-- 6) PIN을 무염 SHA-256 → bcrypt(crypt/bf) 서버 검증으로 전환
--
-- 주의: MCP 서버의 storage 접근은 이제 anon 정책이 아닌 mcp-storage Edge Function(service role) 경유.

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- ============================================
-- 1. 위험 정책 제거
-- ============================================
DROP POLICY IF EXISTS "user_profiles_anon_mcp_check" ON user_profiles;
DROP POLICY IF EXISTS "storage_insert_mcp" ON storage.objects;
DROP POLICY IF EXISTS "storage_select_mcp" ON storage.objects;
DROP POLICY IF EXISTS "storage_delete_mcp" ON storage.objects;

-- ============================================
-- 2. MCP API 키 해시 저장 전환
-- ============================================
ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS mcp_api_key_hash TEXT UNIQUE,
  ADD COLUMN IF NOT EXISTS mcp_key_prefix TEXT,
  ADD COLUMN IF NOT EXISTS mcp_key_created_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS mcp_key_last_used_at TIMESTAMPTZ;

-- 기존 평문 키를 해시로 이관 (기존 클라이언트 키는 계속 동작)
UPDATE user_profiles
SET mcp_api_key_hash = encode(extensions.digest(mcp_api_key, 'sha256'), 'hex'),
    mcp_key_prefix = left(mcp_api_key, 4),
    mcp_key_created_at = COALESCE(mcp_key_created_at, now())
WHERE mcp_api_key IS NOT NULL AND mcp_api_key_hash IS NULL;

-- 평문 컬럼 제거
DROP INDEX IF EXISTS idx_user_profiles_mcp_api_key;
ALTER TABLE user_profiles DROP COLUMN IF EXISTS mcp_api_key;

CREATE INDEX IF NOT EXISTS idx_user_profiles_mcp_api_key_hash
  ON user_profiles(mcp_api_key_hash)
  WHERE mcp_api_key_hash IS NOT NULL;

-- 키 생성: drop_ + 32자 base64url (24바이트 엔트로피), 평문은 생성 시 1회만 반환
CREATE OR REPLACE FUNCTION generate_mcp_api_key()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  new_key TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  new_key := 'drop_' || translate(encode(gen_random_bytes(24), 'base64'), '+/=', 'Aa0');

  INSERT INTO user_profiles (user_id, mcp_api_key_hash, mcp_key_prefix, mcp_key_created_at, mcp_key_last_used_at)
  VALUES (auth.uid(), encode(digest(new_key, 'sha256'), 'hex'), left(new_key, 9), now(), NULL)
  ON CONFLICT (user_id)
  DO UPDATE SET
    mcp_api_key_hash = EXCLUDED.mcp_api_key_hash,
    mcp_key_prefix = EXCLUDED.mcp_key_prefix,
    mcp_key_created_at = EXCLUDED.mcp_key_created_at,
    mcp_key_last_used_at = NULL,
    updated_at = now();

  RETURN new_key;
END;
$$;

-- 기존 키는 해시라 재표시 불가: 있으면 마스킹된 프리픽스 반환, 없으면 새로 생성해 평문 반환
CREATE OR REPLACE FUNCTION get_mcp_api_key()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  key_prefix TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT mcp_key_prefix INTO key_prefix
  FROM user_profiles
  WHERE user_id = auth.uid() AND mcp_api_key_hash IS NOT NULL;

  IF key_prefix IS NULL THEN
    RETURN generate_mcp_api_key();
  END IF;

  RETURN key_prefix || '…(재발급 필요 시 regenerate)';
END;
$$;

CREATE OR REPLACE FUNCTION regenerate_mcp_api_key()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  RETURN generate_mcp_api_key();
END;
$$;

-- 키 검증: 해시 비교 + last_used 갱신
CREATE OR REPLACE FUNCTION mcp_validate_key(api_key TEXT)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  uid UUID;
BEGIN
  SELECT user_id INTO uid
  FROM user_profiles
  WHERE mcp_api_key_hash = encode(digest(api_key, 'sha256'), 'hex');

  IF uid IS NULL THEN
    RAISE EXCEPTION 'Invalid API key';
  END IF;

  UPDATE user_profiles
  SET mcp_key_last_used_at = now()
  WHERE user_id = uid
    AND (mcp_key_last_used_at IS NULL OR mcp_key_last_used_at < now() - interval '1 minute');

  RETURN uid;
END;
$$;

-- MCP 서버 호환용 (Edge Function/서버에서 사용) — 해시 조회로 변경
CREATE OR REPLACE FUNCTION get_user_id_by_mcp_key(api_key TEXT)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  found_user_id UUID;
BEGIN
  SELECT user_id INTO found_user_id
  FROM user_profiles
  WHERE mcp_api_key_hash = encode(digest(api_key, 'sha256'), 'hex');

  RETURN found_user_id;
END;
$$;

-- 키 관리 함수는 authenticated 전용
REVOKE EXECUTE ON FUNCTION generate_mcp_api_key() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION get_mcp_api_key() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION regenerate_mcp_api_key() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION generate_mcp_api_key() TO authenticated;
GRANT EXECUTE ON FUNCTION get_mcp_api_key() TO authenticated;
GRANT EXECUTE ON FUNCTION regenerate_mcp_api_key() TO authenticated;

-- ============================================
-- 3. 소유권 체크 누락 수정 (mcp_remove_tags_from_note)
-- ============================================
CREATE OR REPLACE FUNCTION mcp_remove_tags_from_note(api_key TEXT, p_note_id UUID, p_tag_names TEXT[])
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  uid UUID;
  tag_name TEXT;
  removed TEXT[] := '{}';
BEGIN
  uid := mcp_validate_key(api_key);

  IF NOT EXISTS (SELECT 1 FROM notes WHERE id = p_note_id AND user_id = uid) THEN
    RAISE EXCEPTION 'Note not found';
  END IF;

  FOREACH tag_name IN ARRAY p_tag_names LOOP
    DELETE FROM note_tags
    WHERE note_id = p_note_id
      AND tag_id = (SELECT id FROM tags WHERE name = tag_name AND user_id = uid);

    IF FOUND THEN
      removed := array_append(removed, tag_name);
    END IF;
  END LOOP;

  RETURN json_build_object('success', true, 'removed_tags', removed);
END;
$$;

-- ============================================
-- 4. p_limit / p_offset SQL단 클램프
-- ============================================
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
           created_at, updated_at, deleted_at, archived_at
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

CREATE OR REPLACE FUNCTION mcp_list_tags(api_key TEXT, p_limit INT DEFAULT 50)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  uid UUID;
  v_limit INT := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200);
BEGIN
  uid := mcp_validate_key(api_key);

  RETURN (
    SELECT json_build_object('tags', COALESCE(json_agg(t ORDER BY note_count DESC), '[]'::json))
    FROM (
      SELECT t.id, t.name, COUNT(nt.note_id) as note_count
      FROM tags t
      LEFT JOIN note_tags nt ON t.id = nt.tag_id
      LEFT JOIN notes n ON nt.note_id = n.id AND n.deleted_at IS NULL
      WHERE t.user_id = uid
      GROUP BY t.id, t.name
      LIMIT v_limit
    ) t
  );
END;
$$;

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
      SELECT n.id, n.display_id, n.content, n.created_at, n.has_link, n.has_media, n.has_files
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
      SELECT DISTINCT n.id, n.display_id, n.content, n.created_at, n.has_link, n.has_media, n.has_files
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
      SELECT id, display_id, content, created_at, has_link, has_media, has_files
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

-- ============================================
-- 5. PIN: bcrypt 서버 검증으로 전환
-- ============================================
-- 기존 pin_hash(클라이언트 무염 SHA-256)는 무효화 — PIN 재설정 필요
CREATE OR REPLACE FUNCTION set_note_pin(p_pin TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  IF p_pin IS NULL OR length(p_pin) < 4 OR length(p_pin) > 12 THEN
    RAISE EXCEPTION 'PIN must be 4-12 characters';
  END IF;

  INSERT INTO user_profiles (user_id, pin_hash)
  VALUES (auth.uid(), crypt(p_pin, gen_salt('bf', 10)))
  ON CONFLICT (user_id)
  DO UPDATE SET pin_hash = crypt(p_pin, gen_salt('bf', 10)), updated_at = now();

  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION verify_note_pin(p_pin TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  stored_hash TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT pin_hash INTO stored_hash FROM user_profiles WHERE user_id = auth.uid();

  IF stored_hash IS NULL THEN
    RETURN false;
  END IF;

  -- bcrypt 해시가 아니면(구 SHA-256 잔재) 무효 처리
  IF stored_hash NOT LIKE '$2%' THEN
    RETURN false;
  END IF;

  RETURN stored_hash = crypt(p_pin, stored_hash);
END;
$$;

CREATE OR REPLACE FUNCTION has_note_pin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  RETURN EXISTS (
    SELECT 1 FROM user_profiles
    WHERE user_id = auth.uid() AND pin_hash LIKE '$2%'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION set_note_pin(TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION verify_note_pin(TEXT) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION has_note_pin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION set_note_pin(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION verify_note_pin(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION has_note_pin() TO authenticated;

-- pin_hash를 클라이언트가 직접 읽을 필요 제거 → 자체 프로필 SELECT에서도 민감 컬럼 노출 방지용
-- (기존 정책이 전체 컬럼 SELECT를 허용하므로, 클라이언트는 이후 RPC만 사용)

-- ============================================
-- 6. 남은 SECURITY DEFINER 함수 일괄 search_path 고정
-- ============================================
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS fn
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prosecdef
      AND NOT EXISTS (
        SELECT 1 FROM unnest(COALESCE(p.proconfig, '{}')) cfg
        WHERE cfg LIKE 'search_path=%'
      )
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public, pg_temp', r.fn);
  END LOOP;
END $$;
