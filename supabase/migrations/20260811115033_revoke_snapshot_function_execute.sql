-- snapshot_note_content()는 트리거 전용 함수인데, 기본 EXECUTE 권한이 PUBLIC에 있어
-- PostgREST의 /rest/v1/rpc/snapshot_note_content 로 anon·authenticated에게 노출된다
-- (Supabase security advisor: anon/authenticated_security_definer_function_executable).
--
-- 직접 호출은 트리거 컨텍스트가 없어 실패하지만, SECURITY DEFINER 함수를 굳이 공개 API
-- 표면에 남길 이유가 없다. 트리거 실행은 EXECUTE 권한을 검사하지 않으므로 회수해도
-- 스냅샷 동작에는 영향이 없다.

REVOKE ALL ON FUNCTION public.snapshot_note_content() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.snapshot_note_content() FROM anon;
REVOKE ALL ON FUNCTION public.snapshot_note_content() FROM authenticated;
