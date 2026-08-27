-- BRU-115 Rule B — 휴지통에서 나오면 항상 활성이다.
--
-- 실행: make db-test  (= supabase test db)
--
-- 이 테스트가 지키는 것:
--   1) deleted_at만 채워도 archived_at이 비워진다 (데스크톱 옛 경로·MCP)
--   2) 복원하면 archived_at이 되살아나지 않는다
--   3) 활성 노트를 보관하는 정상 경로는 건드리지 않는다

BEGIN;

SELECT plan(5);

CREATE TEMP TABLE t_user AS SELECT id FROM auth.users LIMIT 1;

INSERT INTO public.notes (id, content, source, user_id, archived_at)
SELECT 'aaaaaaaa-1111-4111-8111-000000000001', '보관된 메모', 'desktop', id, now()
FROM t_user;

-- 클라이언트가 데스크톱 옛 경로처럼 deleted_at만 보낸다.
UPDATE public.notes
SET deleted_at = now(), is_deleted = true
WHERE id = 'aaaaaaaa-1111-4111-8111-000000000001';

SELECT is(
  (SELECT archived_at FROM public.notes WHERE id = 'aaaaaaaa-1111-4111-8111-000000000001'),
  NULL,
  '휴지통으로 보낼 때 archived_at을 비운다'
);
SELECT ok(
  (SELECT deleted_at IS NOT NULL FROM public.notes WHERE id = 'aaaaaaaa-1111-4111-8111-000000000001'),
  'deleted_at은 남는다'
);

-- 이중 플래그 행을 트리거 밖에서 만들고 복원한다.
ALTER TABLE public.notes DISABLE TRIGGER notes_trash_clears_archive;
UPDATE public.notes
SET archived_at = now()
WHERE id = 'aaaaaaaa-1111-4111-8111-000000000001';
ALTER TABLE public.notes ENABLE TRIGGER notes_trash_clears_archive;

UPDATE public.notes
SET deleted_at = NULL, is_deleted = false
WHERE id = 'aaaaaaaa-1111-4111-8111-000000000001';

SELECT is(
  (SELECT archived_at FROM public.notes WHERE id = 'aaaaaaaa-1111-4111-8111-000000000001'),
  NULL,
  '복원해도 archived_at을 다시 살리지 않는다'
);
SELECT is(
  (SELECT deleted_at FROM public.notes WHERE id = 'aaaaaaaa-1111-4111-8111-000000000001'),
  NULL,
  '복원하면 deleted_at도 비워진다'
);

-- 활성 → 보관은 그대로여야 한다.
INSERT INTO public.notes (id, content, source, user_id)
SELECT 'aaaaaaaa-1111-4111-8111-000000000002', '그냥 메모', 'desktop', id
FROM t_user;

UPDATE public.notes
SET archived_at = now()
WHERE id = 'aaaaaaaa-1111-4111-8111-000000000002';

SELECT ok(
  (SELECT archived_at IS NOT NULL FROM public.notes WHERE id = 'aaaaaaaa-1111-4111-8111-000000000002'),
  '활성 노트를 보관하면 archived_at이 유지된다'
);

SELECT * FROM finish();

ROLLBACK;
