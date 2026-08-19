-- BRU-67: has_link / has_media / has_files 계산을 DB 한 곳으로 모은다.
--
-- 원인 (실측, 2026-08-19 프로덕션 노트 183건):
--   1) 계산 지점이 클라이언트에 흩어져 있었고 그나마 데스크톱에만 있었다.
--      - 데스크톱 renderer: calculateNoteCategories()로 계산해서 write
--      - mcp_create_note() / mcp_update_note(): has_link을 아예 건드리지 않음
--        → source='mcp' 노트(#62 https://work-salon.pages.dev/,
--          #61 https://contentsalon.pages.dev/coaching)는 URL이 있어도 계속 false
--      - iOS/Android: NotesRepository.updateCategories()는 있으나 노트 생성·수정
--        경로에서 호출되지 않음 → source='mobile' 노트(#85 youtube URL)도 false
--   2) 데스크톱 계산 자체도 깨져 있었다. hasUrlInText()가 /g 플래그 정규식 상수에
--      .test()를 호출해 lastIndex가 호출 사이에 남았고, URL 있는 노트가 하나 걸러
--      하나씩 false로 판정됐다. 같은 배치 안에서 결과가 갈린 이유다.
--      (별도 커밋에서 수정: apps/desktop/src/renderer/lib/url-utils.ts)
--
-- 이제 어느 클라이언트가 무엇을 써 보내든 DB 트리거가 최종값을 정한다.

-- ============================================
-- 1. 본문 URL 판정 — 단일 정의
-- ============================================
-- 클라이언트 정규식과 같은 패턴:
--   /https?:\/\/[^\s<>"{}|\\^`[\]]+/i
-- 대소문자 무시(~*)여야 한다 — `HTTPS://…`로 시작하는 본문이 실제로 있다.
CREATE OR REPLACE FUNCTION note_content_has_url(p_content TEXT)
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
SET search_path = ''
AS $$
  SELECT COALESCE(p_content, '') ~* 'https?://[^\s<>"{}|\\^`\[\]]+';
$$;

COMMENT ON FUNCTION note_content_has_url(TEXT) IS
  'BRU-67: 노트 본문에 http(s) URL이 있는지. has_link 판정의 유일한 정의.';

-- ============================================
-- 2. 노트 카테고리 플래그 — 단일 정의
-- ============================================
CREATE OR REPLACE FUNCTION note_categories(p_note_id UUID, p_content TEXT)
RETURNS TABLE (has_link BOOLEAN, has_media BOOLEAN, has_files BOOLEAN)
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
  SELECT
    public.note_content_has_url(p_content)
      OR COALESCE(bool_or(a.type IN ('instagram', 'youtube')), false),
    COALESCE(bool_or(a.type IN ('image', 'video', 'audio')), false),
    COALESCE(bool_or(a.type IN ('file', 'text')), false)
  FROM public.attachments a
  WHERE a.note_id = p_note_id;
$$;

COMMENT ON FUNCTION note_categories(UUID, TEXT) IS
  'BRU-67: 노트의 has_link/has_media/has_files 값. 트리거와 백필이 모두 이것만 쓴다.';

-- ============================================
-- 3. notes 트리거 — 클라이언트가 보낸 값을 덮어쓴다
-- ============================================
CREATE OR REPLACE FUNCTION notes_sync_categories()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  SELECT c.has_link, c.has_media, c.has_files
  INTO NEW.has_link, NEW.has_media, NEW.has_files
  FROM note_categories(NEW.id, NEW.content) c;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notes_sync_categories ON notes;
CREATE TRIGGER notes_sync_categories
  BEFORE INSERT OR UPDATE ON notes
  FOR EACH ROW
  EXECUTE FUNCTION notes_sync_categories();

-- ============================================
-- 4. attachments 트리거 — 첨부가 바뀌면 노트 플래그를 다시 맞춘다
-- ============================================
CREATE OR REPLACE FUNCTION attachments_sync_note_categories()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  -- 첨부가 다른 노트로 옮겨간 경우 양쪽 노트를 모두 다시 맞춘다.
  -- 플래그가 실제로 달라질 때만 쓴다 (updated_at을 괜히 흔들지 않기 위해).
  UPDATE notes n
  SET has_link = c.has_link,
      has_media = c.has_media,
      has_files = c.has_files
  FROM (
    SELECT m.id, k.has_link, k.has_media, k.has_files
    FROM notes m
    CROSS JOIN LATERAL note_categories(m.id, m.content) k
    WHERE m.id IN (COALESCE(NEW.note_id, OLD.note_id), COALESCE(OLD.note_id, NEW.note_id))
  ) c
  WHERE n.id = c.id
    AND (n.has_link, n.has_media, n.has_files)
        IS DISTINCT FROM (c.has_link, c.has_media, c.has_files);

  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS attachments_sync_note_categories ON attachments;
CREATE TRIGGER attachments_sync_note_categories
  AFTER INSERT OR UPDATE OR DELETE ON attachments
  FOR EACH ROW
  EXECUTE FUNCTION attachments_sync_note_categories();

-- ============================================
-- 5. 기존 노트 백필
-- ============================================
-- notes_updated_at 트리거를 잠시 끈다 — 플래그 교정이 노트의 updated_at을
-- 오늘 날짜로 밀어버리면 피드 정렬과 "언제 쓴 메모인지"가 망가진다.
-- notes_snapshot_content는 content가 안 바뀌면 아무것도 하지 않으므로 그대로 둔다.
ALTER TABLE notes DISABLE TRIGGER notes_updated_at;

UPDATE notes n
SET has_link = c.has_link,
    has_media = c.has_media,
    has_files = c.has_files
FROM (
  SELECT m.id, k.has_link, k.has_media, k.has_files
  FROM notes m
  CROSS JOIN LATERAL note_categories(m.id, m.content) k
) c
WHERE n.id = c.id
  AND (n.has_link, n.has_media, n.has_files)
      IS DISTINCT FROM (c.has_link, c.has_media, c.has_files);

ALTER TABLE notes ENABLE TRIGGER notes_updated_at;
