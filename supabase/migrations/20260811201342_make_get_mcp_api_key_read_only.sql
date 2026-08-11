-- get_mcp_api_key()를 조회 전용으로 되돌린다.
--
-- 기존 구현은 두 가지가 얽혀 있었다:
--   1) 발급 이력이 없으면 그 자리에서 키를 발급한다 (조회 함수의 부작용)
--   2) 이미 있으면 평문 대신 '<접두사>…(재발급 필요 시 regenerate)' 문자열을 돌려준다
--
-- (2) 때문에 UI가 오작동했다. 접두사는 left(key, 9) = 'drop_xxxx'라서 반환값이 여전히
-- 'drop_'로 시작하고, UI는 이를 평문 키로 오인해 안내 문구가 섞인 문자열을 클립보드에
-- 복사했다. (1)은 UI가 발급 여부를 확인만 하려 해도 키가 생기게 만든다.
--
-- 이제 발급은 generate/regenerate만 한다. 조회는 접두사 또는 NULL만 돌려준다.

CREATE OR REPLACE FUNCTION public.get_mcp_api_key()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  key_prefix TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT mcp_key_prefix INTO key_prefix
  FROM user_profiles
  WHERE user_id = auth.uid() AND mcp_api_key_hash IS NOT NULL;

  -- 발급 이력이 없으면 NULL. 여기서 발급하지 않는다.
  RETURN key_prefix;
END;
$function$;
