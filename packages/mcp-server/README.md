# drop-mcp

MCP server for Braindump notes. Access your notes from AI assistants like Claude.

## Installation

```bash
npm install -g @brxce/drop-mcp
```

## Configuration

### Getting Your Token

1. Open the Braindump app
2. Go to Profile → Copy MCP Token

### Environment Variables

The server requires:

- `DROP_TOKEN` - Your MCP token from the Braindump app
- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_ANON_KEY` - Your Supabase anon (public) key

### Claude Code / Desktop

Add to `.mcp.json`:

```json
{
  "mcpServers": {
    "drop": {
      "command": "drop-mcp",
      "env": {
        "DROP_TOKEN": "your-token",
        "SUPABASE_URL": "https://your-project.supabase.co",
        "SUPABASE_ANON_KEY": "your-anon-key"
      }
    }
  }
}
```

## Available Tools

### Notes

- `list_notes` - List recent notes with pagination
- `get_note` - Get a single note with tags and attachments
- `create_note` - Create a new note
- `update_note` - Update an existing note
- `delete_note` - Soft-delete a note (move to trash)
- `archive_note` - Archive a note
- `set_note_export` - Mark a note as exported to a Linear issue (records the issue URL)
- `clear_note_export` - Remove the export mark

### Search

- `search_notes` - Search notes by text content
- `search_by_date_range` - Search notes within a date range

### Tags

- `list_tags` - List all tags with note counts
- `get_notes_by_tag` - Get all notes with a specific tag
- `add_tags_to_note` - Add tags to a note
- `remove_tags_from_note` - Remove tags from a note

### Attachments

- `upload_attachment` - Upload an attachment (base64)
- `upload_from_path` - Upload a local file by path
- `list_attachments` - List all attachments for a note
- `delete_attachment` - Delete an attachment

Attachment storage operations (upload, signed URLs, delete) go through the
`mcp-storage` Edge Function, authenticated with your MCP token. The private
`attachments` bucket is not accessible with the anon key. No change to your
user configuration is needed.

## Examples

### List recent notes

```
Use the list_notes tool to show my recent notes
```

### Search notes

```
Search my notes for "meeting"
```

### Create a note with tags

```
Create a note with content "Remember to buy groceries" and add the tag "todo"
```

### Upload an image

```
Upload the file at /path/to/image.png to note <note-id>
```

### Turn a note into a Linear issue (BRU-45)

이 서버는 이슈를 **만들지 않는다.** Drop에 Linear 토큰을 두지 않기 위해서다.
이슈 생성은 Linear MCP가 하고, 이 서버는 그 결과를 노트에 적기만 한다.

```
1. list_notes로 아직 반출되지 않은 노트를 고른다 (exportedTo가 null인 것)
2. Linear MCP로 이슈를 만든다 — 본문에 `Drop #<displayId>` 역링크를 남긴다
3. set_note_export로 이슈 URL과 식별자(BRU-96)를 노트에 적는다
```

적는 순간 그 노트는 Drop 기본 목록과 Inbox 수에서 빠지고, 카드에는 이슈 뱃지가
붙는다. 잘못 반출했으면 `clear_note_export`(또는 데스크톱 카드의 뱃지 옆 ×)로 되돌린다.

## Development

```bash
# Clone the repository
git clone https://github.com/intellieffect/drop.git
cd drop/packages/mcp-server

# Install dependencies
pnpm install

# Build
pnpm build

# Run locally (get token from Braindump app → Profile → Copy MCP Token)
SUPABASE_URL=https://your-project.supabase.co \
SUPABASE_ANON_KEY=your-anon-key \
DROP_TOKEN=your-api-key pnpm start
```

## License

MIT

## 동작 확인 (스모크 테스트)

```bash
pnpm build
DROP_TOKEN=drop_xxx pnpm smoke
```

MCP 프로토콜을 실제로 태워 핸드셰이크 → 인증 → 노트 생성·수정·조회·검색·태그·삭제까지 확인한다.
`SUPABASE_URL` / `SUPABASE_ANON_KEY`를 생략하면 로컬 스택(`supabase start`)을 본다.

노트를 만들고 지우므로 실제 계정이 아닌 테스트 계정에서 돌린다.
