-- 노트 편집 히스토리 (BRU-3)
--
-- 지금까지 노트 수정 시 이전 내용은 그대로 소실됐다 (updated_at 갱신 + 소프트삭제가 전부).
-- 언두 토스트는 삭제만 커버하고 편집은 커버하지 않는다.
--
-- 설계 선택:
-- 1) 클라이언트 스냅샷이 아니라 **트리거**로 서버에서 남긴다 — 데스크톱·모바일·MCP 어느 경로로
--    수정해도 동일하게 기록되고, 클라이언트가 죽어도 유실되지 않는다.
-- 2) 보존 정책은 **노트당 최근 20개**를 트리거 안에서 잘라낸다 — pg_cron 의존 없이 자정리되고,
--    "30일" 같은 시간 기준과 달리 오래된 노트의 마지막 히스토리가 사라지지 않는다.
-- 3) 쓰기는 트리거(SECURITY DEFINER)만 한다 — authenticated에는 INSERT/UPDATE 정책을 주지 않는다.
--    사용자는 자기 히스토리를 읽고 지울 수만 있다.

CREATE TABLE note_revisions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id UUID NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  -- now()가 아니라 clock_timestamp(): now()는 트랜잭션 시작 시각이라
  -- 한 트랜잭션에서 여러 번 수정하면 스냅샷들이 같은 시각을 갖고 정렬 순서가 뒤섞인다.
  -- 그러면 "직전 버전으로 복원"과 보존 정책의 잘라내기 대상이 임의로 정해진다.
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

COMMENT ON TABLE note_revisions IS '노트 편집 직전 content 스냅샷. 노트당 최근 20개만 보존(트리거에서 정리).';

-- 노트별 최신순 조회가 유일한 접근 패턴
CREATE INDEX idx_note_revisions_note_id_created_at
  ON note_revisions(note_id, created_at DESC);

-- ============================================
-- 스냅샷 트리거
-- ============================================

CREATE OR REPLACE FUNCTION snapshot_note_content()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  keep_count CONSTANT INTEGER := 20;
BEGIN
  -- content가 실제로 바뀐 경우에만 기록한다.
  -- 고정/우선순위/보관 같은 다른 컬럼 갱신은 히스토리를 남기지 않는다.
  IF OLD.content IS NOT DISTINCT FROM NEW.content THEN
    RETURN NEW;
  END IF;

  -- 빈 노트에서 처음 내용을 채우는 경우는 되돌릴 것이 없다.
  IF OLD.content IS NULL OR OLD.content = '' THEN
    RETURN NEW;
  END IF;

  INSERT INTO note_revisions (note_id, content)
  VALUES (OLD.id, OLD.content);

  -- 보존 정책: 노트당 최근 keep_count개만 남긴다.
  DELETE FROM note_revisions
  WHERE id IN (
    SELECT id FROM note_revisions
    WHERE note_id = OLD.id
    ORDER BY created_at DESC, id DESC
    OFFSET keep_count
  );

  RETURN NEW;
END;
$$;

CREATE TRIGGER notes_snapshot_content
  BEFORE UPDATE ON notes
  FOR EACH ROW
  EXECUTE FUNCTION snapshot_note_content();

-- ============================================
-- RLS — 소유자 전용
-- ============================================

ALTER TABLE note_revisions ENABLE ROW LEVEL SECURITY;

-- 읽기: 자기 노트의 히스토리만
CREATE POLICY "note_revisions_select_own" ON note_revisions FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM notes
    WHERE notes.id = note_revisions.note_id AND notes.user_id = auth.uid()
  ));

-- 삭제: 자기 노트의 히스토리만 (히스토리 비우기용)
CREATE POLICY "note_revisions_delete_own" ON note_revisions FOR DELETE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM notes
    WHERE notes.id = note_revisions.note_id AND notes.user_id = auth.uid()
  ));

-- INSERT/UPDATE 정책은 의도적으로 없다 — 기록은 트리거만 한다.

GRANT SELECT, DELETE ON note_revisions TO authenticated;
GRANT ALL ON note_revisions TO service_role;
