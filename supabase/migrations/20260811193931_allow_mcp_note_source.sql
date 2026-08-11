-- MCP로 만든 노트의 source 값을 허용한다.
--
-- mcp_create_note()는 처음부터 source='mcp'로 INSERT했는데(20260102005914_add_mcp_api_key.sql:242),
-- notes_source_check는 mobile|desktop|web만 허용한다. 그래서 MCP 경유 노트 생성은
-- 도입 이후 한 번도 성공한 적이 없다:
--
--   new row for relation "notes" violates check constraint "notes_source_check"
--
-- 함수를 desktop으로 위장시키는 대신 제약을 넓힌다 — 어디서 들어온 노트인지는
-- 실제로 구분 가치가 있는 정보다.

ALTER TABLE notes DROP CONSTRAINT notes_source_check;

ALTER TABLE notes ADD CONSTRAINT notes_source_check
  CHECK (source = ANY (ARRAY['mobile'::text, 'desktop'::text, 'web'::text, 'mcp'::text]));
