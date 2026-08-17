-- 로컬 개발용 시드 (BRU-71)
--
-- 데스크톱을 로그인 없이 띄워 화면을 눈으로 확인하기 위한 데이터다.
-- 앱은 VITE_DROP_PREVIEW=1 일 때 아래 사용자로 이메일 로그인한다
-- (apps/desktop/src/renderer/lib/preview-session.ts).
--
-- 비밀번호가 여기 그대로 있어도 되는 이유: 이 사용자는 로컬 컨테이너 안에만 있다.
-- 이 파일은 `supabase db reset`에서만 실행되고 리모트에는 나가지 않는다.

-- ---------------------------------------------------------------------------
-- 시드 사용자
-- ---------------------------------------------------------------------------
-- 토큰 컬럼들을 빈 문자열로 채우는 이유: GoTrue가 이 컬럼들을 NOT NULL 문자열로
-- 읽어서, NULL로 두면 로그인이 500 "Database error querying schema"로 떨어진다.
-- (2026-08-18 실측 — 이것 때문에 첫 시도가 실패했다.)
INSERT INTO auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data,
  confirmation_token, recovery_token,
  email_change, email_change_token_new, email_change_token_current,
  phone_change, phone_change_token, reauthentication_token
)
VALUES (
  '00000000-0000-4000-8000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated',
  'preview@drop.local',
  -- bcrypt('drop-preview-password')
  crypt('drop-preview-password', gen_salt('bf')),
  now(), now(), now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"full_name":"Preview User"}'::jsonb,
  '', '', '', '', '', '', '', ''
)
ON CONFLICT (id) DO NOTHING;

-- 이메일 로그인은 identities 행이 있어야 통과한다.
INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
)
VALUES (
  '00000000-0000-4000-8000-000000000002',
  '00000000-0000-4000-8000-000000000001',
  '{"sub":"00000000-0000-4000-8000-000000000001","email":"preview@drop.local"}'::jsonb,
  'email', 'preview@drop.local', now(), now(), now()
)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 표본 노트 — 최근 붙은 표현이 한 화면에 다 보이게
--   · 계층 답글 2단 (BRU-70)
--   · Linear 반출 뱃지 (BRU-45)
--   · 태그 · 고정 · 긴급도
-- ---------------------------------------------------------------------------
INSERT INTO notes (id, user_id, display_id, content, parent_id, source, created_at, updated_at,
                   is_pinned, pinned_at, priority,
                   linear_issue_url, linear_issue_key, linear_exported_at)
VALUES
  ('00000000-0000-4000-8000-000000000101',
   '00000000-0000-4000-8000-000000000001', 1,
   'iOS 네이티브 전환 — 홈 화면까지 올라왔다', NULL, 'desktop',
   now() - interval '2 hours', now(), true, now(), 3, NULL, NULL, NULL),

  ('00000000-0000-4000-8000-000000000102',
   '00000000-0000-4000-8000-000000000001', 2,
   '장보기: 우유, 커피 원두, 사과', NULL, 'mobile',
   now() - interval '1 hour', now(), false, NULL, 2, NULL, NULL, NULL),

  -- 답글 1단
  ('00000000-0000-4000-8000-000000000103',
   '00000000-0000-4000-8000-000000000001', 3,
   '원두는 지난번 것으로', '00000000-0000-4000-8000-000000000102', 'desktop',
   now() - interval '30 minutes', now(), false, NULL, 0, NULL, NULL, NULL),

  -- 답글 2단
  ('00000000-0000-4000-8000-000000000104',
   '00000000-0000-4000-8000-000000000001', 4,
   '품절이면 다른 것도 괜찮다', '00000000-0000-4000-8000-000000000103', 'desktop',
   now() - interval '15 minutes', now(), false, NULL, 0, NULL, NULL, NULL),

  -- 반출된 노트 — 기본 목록에서는 빠지고 "반출됨" 토글을 켜야 보인다
  ('00000000-0000-4000-8000-000000000105',
   '00000000-0000-4000-8000-000000000001', 5,
   '노트를 Linear 이슈로 보내는 파이프라인이 필요하다', NULL, 'mcp',
   now() - interval '3 hours', now(), false, NULL, 1,
   'https://linear.app/intellieffect/issue/BRU-45/inbox-분류-linear-반출-파이프라인',
   'BRU-45', now() - interval '10 minutes'),

  -- 태그 없는 노트 = Inbox
  ('00000000-0000-4000-8000-000000000106',
   '00000000-0000-4000-8000-000000000001', 6,
   '아직 분류하지 않은 덤프', NULL, 'mobile',
   now() - interval '20 minutes', now(), false, NULL, 0, NULL, NULL, NULL)
ON CONFLICT (id) DO NOTHING;

INSERT INTO tags (id, user_id, name, created_at)
VALUES
  ('00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000001', '개발', now()),
  ('00000000-0000-4000-8000-000000000202', '00000000-0000-4000-8000-000000000001', '생활', now())
ON CONFLICT (id) DO NOTHING;

INSERT INTO note_tags (note_id, tag_id)
VALUES
  ('00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000000201'),
  ('00000000-0000-4000-8000-000000000102', '00000000-0000-4000-8000-000000000202')
ON CONFLICT DO NOTHING;
