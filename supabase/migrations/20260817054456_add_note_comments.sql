-- 노트 댓글 (BRU-61 / BRU-62)
--
-- 지금까지 노트에 무언가를 덧붙이는 길은 `notes.parent_id`(하위 노트) 하나뿐이었다.
-- 그래서 "확인/제안" 같은 짧은 응답이 전부 독립 노트로 피드에 쌓였다.
--
-- 설계 선택:
-- 1) **별도 테이블**이다. `notes`에 kind 컬럼을 두는 안은 목록·검색·Inbox·위젯 등
--    노트를 읽는 모든 경로에 "댓글 제외" 조건을 붙여야 하고, 한 곳만 빠뜨려도
--    댓글이 노트처럼 튀어나온다. 구조로 막는 쪽을 택했다.
-- 2) `notes.parent_id`는 그대로 둔다 — 하위 노트와 댓글은 다른 것이다.
-- 3) 댓글은 노트 속성(태그·첨부·우선순위·보관·잠금)을 갖지 않는다. 본문과 시각뿐이다.
-- 4) 소프트 삭제 없음. 노트를 휴지통에 넣어도 댓글은 남고(복원하면 그대로 보인다),
--    노트를 영구 삭제할 때만 ON DELETE CASCADE로 함께 사라진다.

CREATE TABLE note_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id UUID NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  body TEXT NOT NULL CHECK (length(btrim(body)) > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE note_comments IS
  '노트에 달린 댓글. 노트가 아니므로 피드·검색·Inbox에 섞이지 않는다. 노트 영구삭제 시 함께 삭제된다.';

-- 유일한 접근 패턴: 노트별 오래된 순 조회
CREATE INDEX idx_note_comments_note_id_created_at
  ON note_comments(note_id, created_at);

CREATE TRIGGER note_comments_updated_at
  BEFORE UPDATE ON note_comments
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

-- ============================================
-- RLS — 소유자 전용
-- ============================================
--
-- 댓글 소유는 두 겹으로 본다: 자기가 쓴 댓글이고(user_id) 자기 노트에 달린 것(notes.user_id).
-- 노트가 남의 것이면 댓글도 보이지 않는다.

ALTER TABLE note_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "note_comments_select_own" ON note_comments FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM notes
      WHERE notes.id = note_comments.note_id AND notes.user_id = auth.uid()
    )
  );

CREATE POLICY "note_comments_insert_own" ON note_comments FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM notes
      WHERE notes.id = note_comments.note_id AND notes.user_id = auth.uid()
    )
  );

CREATE POLICY "note_comments_update_own" ON note_comments FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "note_comments_delete_own" ON note_comments FOR DELETE TO authenticated
  USING (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE, DELETE ON note_comments TO authenticated;
GRANT ALL ON note_comments TO service_role;
