-- 명시적 테이블 권한 부여
-- 최신 Supabase 스택은 public 스키마 새 테이블에 anon/authenticated DML을 기본 부여하지 않는다.
-- 앱은 로그인 필수이므로 authenticated에만 DML을 주고, anon은 무권한 유지(MCP는 SECURITY DEFINER RPC + Edge Function 경유).
-- 행 단위 보호는 기존 RLS 정책이 담당한다.

GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- service_role은 RLS를 우회하지만 테이블 권한 자체는 필요 (관리 작업·Edge Function 대비)
GRANT USAGE ON SCHEMA public TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO service_role;

-- 이후 생성되는 테이블에도 동일 적용
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO authenticated;
