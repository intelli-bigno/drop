-- BRU-67 회귀 테스트 — has_link / has_media / has_files 는 DB가 정한다.
--
-- 실행: make db-test  (= supabase test db)
--
-- 이 테스트가 지키는 것:
--   1) 본문 어디에 있든, 어떤 모양이든 URL이면 has_link = true
--   2) 클라이언트가 false를 써 보내도 DB가 고쳐 쓴다 (MCP·모바일 경로)
--   3) 연속으로 여러 건을 넣어도 하나 걸러 하나씩 갈리지 않는다
--      (데스크톱의 /g 정규식 lastIndex 버그가 만들던 증상)

BEGIN;

SELECT plan(29);

CREATE TEMP TABLE t_user AS SELECT id FROM auth.users LIMIT 1;

-- ---------------------------------------------------------------------------
-- 1. note_content_has_url — URL 위치와 모양
-- ---------------------------------------------------------------------------
SELECT ok(public.note_content_has_url('https://work-salon.pages.dev/'), '본문 전체가 URL 하나');
SELECT ok(public.note_content_has_url('https://contentsalon.pages.dev/coaching'), '경로가 붙은 URL');
SELECT ok(
  public.note_content_has_url(E'[네이버지도]\n갓잇 하남미사점\n경기 하남시 미사강변중앙로 193 1층 117, 118호\nhttps://naver.me/GT4UKu03'),
  '여러 줄 끝에 있는 URL'
);
SELECT ok(
  public.note_content_has_url(E'https://www.instagram.com/p/DbNcfjfjxBL/?img_index=2\n\n스토리텔링'),
  '첫 줄 URL + 뒤따르는 본문'
);
SELECT ok(
  public.note_content_has_url('참고: https://example.com/a?b=1&c=2 여기 보면 됨'),
  '문장 가운데 낀 URL'
);
SELECT ok(
  public.note_content_has_url('https://claude.ai/code/artifact/e710516f?via=auto\_preview'),
  '마크다운 이스케이프(\_)가 섞인 URL'
);
SELECT ok(
  public.note_content_has_url('https://web.plaud.ai/s/pub_efb75d5f-dee6-46db-ac9b-f104838ca37a::rPEnXp-tK3yI'),
  '콜론·언더스코어가 들어간 긴 URL'
);
SELECT ok(public.note_content_has_url('http://legacy.example.com'), 'https가 아닌 http');
SELECT ok(public.note_content_has_url(E'끝줄에 URL\nhttps://a.example'), '마지막 줄 URL');

SELECT ok(NOT public.note_content_has_url('그냥 메모 한 줄'), 'URL 없는 본문');
SELECT ok(NOT public.note_content_has_url('example.com 은 스킴이 없다'), '스킴 없는 도메인은 URL이 아니다');
SELECT ok(NOT public.note_content_has_url(''), '빈 문자열');
SELECT ok(NOT public.note_content_has_url(NULL), 'NULL 본문');

-- ---------------------------------------------------------------------------
-- 2. INSERT 트리거 — 클라이언트가 무엇을 써 보내든 DB가 정한다
-- ---------------------------------------------------------------------------
-- MCP 경로 재현: mcp_create_note()는 has_link을 아예 넘기지 않아 기본값 false로 들어왔다.
INSERT INTO public.notes (id, content, source, user_id, has_link)
SELECT '11111111-1111-4111-8111-000000000001', 'https://work-salon.pages.dev/', 'mcp', id, false
FROM t_user;

SELECT is(
  (SELECT has_link FROM public.notes WHERE id = '11111111-1111-4111-8111-000000000001'),
  true,
  'MCP 경로처럼 has_link=false로 INSERT해도 DB가 true로 고친다'
);

-- 모바일 경로 재현
INSERT INTO public.notes (id, content, source, user_id)
SELECT '11111111-1111-4111-8111-000000000002',
       'https://youtube.com/shorts/s3B9yPvj8Bg?si=OPqqy6FxcLbOG2bb', 'mobile', id
FROM t_user;

SELECT is(
  (SELECT has_link FROM public.notes WHERE id = '11111111-1111-4111-8111-000000000002'),
  true,
  '모바일이 has_link을 아예 안 보내도 true'
);

-- 반대 방향: URL이 없는데 true로 써 보내면 false로 내린다
INSERT INTO public.notes (id, content, source, user_id, has_link)
SELECT '11111111-1111-4111-8111-000000000003', 'URL 없는 메모', 'desktop', id, true
FROM t_user;

SELECT is(
  (SELECT has_link FROM public.notes WHERE id = '11111111-1111-4111-8111-000000000003'),
  false,
  'URL이 없으면 클라이언트가 true를 보내도 false'
);

-- ---------------------------------------------------------------------------
-- 3. 연속 INSERT — 하나 걸러 하나씩 갈리지 않는다 (원래 증상의 회귀 테스트)
-- ---------------------------------------------------------------------------
INSERT INTO public.notes (content, source, user_id)
SELECT c, 'mcp', u.id
FROM t_user u,
     unnest(ARRAY[
       'https://work-salon.pages.dev/',
       'https://contentsalon.pages.dev/coaching',
       E'[네이버지도]\n갓잇 하남미사점\nhttps://naver.me/GT4UKu03',
       E'[네이버지도]\n로쏘폴라레\nhttps://naver.me/GQGsHCAs',
       'https://web.plaud.ai/s/pub_efb75d5f',
       'https://claude.ai/code/artifact/e710516f?via=auto\_preview',
       'https://ecombold.com/?utm_source=ig&utm_medium=social'
     ]) AS c;

SELECT is(
  (SELECT count(*)::int FROM public.notes WHERE source = 'mcp' AND content LIKE 'https://%' AND NOT has_link),
  0,
  'URL 노트 7건을 연속으로 넣어도 false가 하나도 없다'
);

-- ---------------------------------------------------------------------------
-- 4. UPDATE 트리거 — 본문이 바뀌면 따라간다
-- ---------------------------------------------------------------------------
UPDATE public.notes SET content = 'URL을 지웠다'
WHERE id = '11111111-1111-4111-8111-000000000001';

SELECT is(
  (SELECT has_link FROM public.notes WHERE id = '11111111-1111-4111-8111-000000000001'),
  false,
  'URL을 지우면 has_link이 false로 내려간다'
);

UPDATE public.notes SET content = E'다시 붙였다\nhttps://naver.me/GT4UKu03'
WHERE id = '11111111-1111-4111-8111-000000000001';

SELECT is(
  (SELECT has_link FROM public.notes WHERE id = '11111111-1111-4111-8111-000000000001'),
  true,
  'URL을 다시 넣으면 true로 올라간다'
);

-- 본문과 무관한 컬럼만 고쳐도 플래그는 유지된다
UPDATE public.notes SET is_pinned = true WHERE id = '11111111-1111-4111-8111-000000000001';

SELECT is(
  (SELECT has_link FROM public.notes WHERE id = '11111111-1111-4111-8111-000000000001'),
  true,
  '핀 같은 다른 컬럼 갱신이 플래그를 날리지 않는다'
);

-- ---------------------------------------------------------------------------
-- 5. 첨부 트리거 — instagram/youtube 첨부도 링크다
-- ---------------------------------------------------------------------------
INSERT INTO public.notes (id, content, source, user_id)
SELECT '11111111-1111-4111-8111-000000000004', 'URL 없는 본문 + 인스타 첨부', 'desktop', id
FROM t_user;

SELECT is(
  (SELECT has_link FROM public.notes WHERE id = '11111111-1111-4111-8111-000000000004'),
  false,
  '첨부 붙기 전에는 false'
);

INSERT INTO public.attachments (id, note_id, type, storage_path)
VALUES ('22222222-2222-4222-8222-000000000001',
        '11111111-1111-4111-8111-000000000004', 'instagram', 'ig/1');

SELECT is(
  (SELECT has_link FROM public.notes WHERE id = '11111111-1111-4111-8111-000000000004'),
  true,
  'instagram 첨부가 붙으면 has_link이 true'
);

INSERT INTO public.attachments (id, note_id, type, storage_path)
VALUES ('22222222-2222-4222-8222-000000000002',
        '11111111-1111-4111-8111-000000000004', 'image', 'img/1'),
       ('22222222-2222-4222-8222-000000000003',
        '11111111-1111-4111-8111-000000000004', 'file', 'f/1');

SELECT is(
  (SELECT has_media FROM public.notes WHERE id = '11111111-1111-4111-8111-000000000004'),
  true,
  'image 첨부가 붙으면 has_media'
);
SELECT is(
  (SELECT has_files FROM public.notes WHERE id = '11111111-1111-4111-8111-000000000004'),
  true,
  'file 첨부가 붙으면 has_files'
);

DELETE FROM public.attachments WHERE id = '22222222-2222-4222-8222-000000000001';

SELECT is(
  (SELECT has_link FROM public.notes WHERE id = '11111111-1111-4111-8111-000000000004'),
  false,
  'instagram 첨부를 지우면 has_link이 다시 false'
);

-- 본문에 URL이 있으면 첨부를 지워도 링크로 남는다
UPDATE public.notes SET content = 'https://a.example/x'
WHERE id = '11111111-1111-4111-8111-000000000004';
DELETE FROM public.attachments WHERE note_id = '11111111-1111-4111-8111-000000000004';

SELECT is(
  (SELECT has_link FROM public.notes WHERE id = '11111111-1111-4111-8111-000000000004'),
  true,
  '첨부가 전부 사라져도 본문 URL이 있으면 has_link 유지'
);
SELECT is(
  (SELECT has_media FROM public.notes WHERE id = '11111111-1111-4111-8111-000000000004'),
  false,
  '첨부가 사라지면 has_media는 false'
);
SELECT is(
  (SELECT has_files FROM public.notes WHERE id = '11111111-1111-4111-8111-000000000004'),
  false,
  '첨부가 사라지면 has_files는 false'
);

-- ---------------------------------------------------------------------------
-- 6. 본문이 없는 노트
-- ---------------------------------------------------------------------------
SELECT ok(
  (SELECT count(*)::int FROM public.notes WHERE has_link AND content IS NULL) = 0,
  '본문이 NULL인 노트가 URL 판정으로 링크가 되지는 않는다'
);

SELECT * FROM finish();

ROLLBACK;
