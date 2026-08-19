-- 프로젝트 (BRU-83)
--
-- 지금까지 분류축은 태그뿐이라 "어느 프로젝트의 것인가"가 태그에 섞여 있었다.
-- 노트를 묶는 상위 개념으로 프로젝트를 들인다.
--
-- 설계 선택:
-- 1) **전용 엔티티**다. 예약 태그 네임스페이스(`project:*`)는 태그와 프로젝트가 같은 목록에
--    섞이고, 읽는 경로마다 접두사를 문자열로 걸러내는 조건을 붙여야 한다. 한 곳만 빠뜨리면
--    프로젝트가 태그처럼 튀어나온다. BRU-61에서 `notes.kind` 대신 별도 테이블을 택한 것과
--    같은 판단 — 구조로 막는다. 색·설명·보관 같은 프로젝트 고유 속성 자리도 생긴다.
-- 2) **단일 소속**이다. `notes.project_id` 하나. 다대다는 "이 노트는 어느 프로젝트 것인가"에
--    답을 못 준다 — 여러 축이 필요하면 그건 태그의 일이다.
-- 3) 프로젝트를 지워도 노트는 남는다 (ON DELETE SET NULL). 분류를 지운다고 원문이 사라지면
--    안 된다 — 이 앱의 첫째 규칙이다.

CREATE TABLE projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (length(btrim(name)) > 0),
  -- 목록에서 눈으로 구분하는 용도. 없으면 앱이 기본색을 쓴다.
  color TEXT,
  description TEXT,
  -- 끝난 프로젝트는 지우지 않고 접는다. 노트는 그대로 매달려 있다.
  archived_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE projects IS
  '노트를 묶는 상위 분류. 노트는 프로젝트 하나에만 속한다(notes.project_id). 태그와는 다른 축이다.';

-- 같은 사람이 이름만 다른 대소문자로 두 개를 만드는 일을 막는다.
-- 사람마다 별개이므로 user_id를 함께 묶는다.
CREATE UNIQUE INDEX idx_projects_user_id_name_lower
  ON projects(user_id, lower(btrim(name)));

-- 사이드바 목록: 사람별 최근 순
CREATE INDEX idx_projects_user_id_created_at
  ON projects(user_id, created_at DESC);

CREATE TRIGGER projects_updated_at
  BEFORE UPDATE ON projects
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at();

-- ============================================
-- notes.project_id — 단일 소속
-- ============================================

ALTER TABLE notes
  ADD COLUMN project_id UUID REFERENCES projects(id) ON DELETE SET NULL;

COMMENT ON COLUMN notes.project_id IS
  '이 노트가 속한 프로젝트. NULL이면 미분류. 프로젝트 삭제 시 NULL이 되고 노트는 남는다.';

-- 프로젝트별 필터의 유일한 접근 패턴. 미분류(NULL)는 인덱스에서 뺀다.
CREATE INDEX idx_notes_project_id
  ON notes(project_id)
  WHERE project_id IS NOT NULL;

-- ============================================
-- RLS — 소유자 전용
-- ============================================

ALTER TABLE projects ENABLE ROW LEVEL SECURITY;

CREATE POLICY "projects_select_own" ON projects FOR SELECT TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "projects_insert_own" ON projects FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "projects_update_own" ON projects FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "projects_delete_own" ON projects FOR DELETE TO authenticated
  USING (user_id = auth.uid());

GRANT SELECT, INSERT, UPDATE, DELETE ON projects TO authenticated;
GRANT ALL ON projects TO service_role;

-- notes의 RLS는 이미 소유자 전용이다. 다만 남의 프로젝트에 자기 노트를 밀어 넣는 길은
-- 막아야 한다 — notes 정책은 notes.user_id만 보므로 project_id의 주인은 따로 검사한다.
CREATE OR REPLACE FUNCTION assert_note_project_owned()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  IF NEW.project_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM projects
    WHERE projects.id = NEW.project_id AND projects.user_id = NEW.user_id
  ) THEN
    RAISE EXCEPTION '노트와 프로젝트의 소유자가 다릅니다';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER notes_project_owner_check
  BEFORE INSERT OR UPDATE OF project_id, user_id ON notes
  FOR EACH ROW
  EXECUTE FUNCTION assert_note_project_owned();
