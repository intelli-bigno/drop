-- BRU-115 Rule B: 휴지통에서 나오면 항상 활성이다.
--
-- 클라이언트가 archived_at을 남겨도 (데스크톱 deleteNote, MCP mcp_delete_note)
-- DB가 지운다. 복원도 마찬가지 — 예전 이중 플래그 행이 보관함으로 되살아나지 않는다.

CREATE OR REPLACE FUNCTION notes_trash_clears_archive()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  -- 휴지통에 들어가 있거나, 휴지통에서 나오는 갱신이면 보관을 비운다.
  IF NEW.deleted_at IS NOT NULL
     OR (TG_OP = 'UPDATE' AND OLD.deleted_at IS NOT NULL) THEN
    NEW.archived_at := NULL;
  END IF;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION notes_trash_clears_archive() IS
  'BRU-115 Rule B: 휴지통 진입·이탈 시 archived_at을 비운다. 복원은 받은편지함으로.';

DROP TRIGGER IF EXISTS notes_trash_clears_archive ON notes;
CREATE TRIGGER notes_trash_clears_archive
  BEFORE INSERT OR UPDATE ON notes
  FOR EACH ROW
  EXECUTE FUNCTION notes_trash_clears_archive();

-- 이미 휴지통에 남은 보관 흔적. updated_at을 오늘로 밀면 피드 정렬이 망가진다.
ALTER TABLE notes DISABLE TRIGGER notes_updated_at;
UPDATE notes
SET archived_at = NULL
WHERE deleted_at IS NOT NULL AND archived_at IS NOT NULL;
ALTER TABLE notes ENABLE TRIGGER notes_updated_at;
