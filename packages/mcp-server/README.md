# drop-mcp

MCP server for DROP notes. Access your notes from AI assistants like Claude.

## Installation

```bash
npm install -g @brxce/drop-mcp
```

## Configuration

### Getting Your Token

1. Open the DROP app
2. Go to Profile → Copy MCP Token

### Environment Variables

The server requires:

- `DROP_TOKEN` - Your MCP token from the DROP app
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

## Development

```bash
# Clone the repository
git clone https://github.com/intellieffect/drop.git
cd drop/packages/mcp-server

# Install dependencies
pnpm install

# Build
pnpm build

# Run locally (get token from DROP app → Profile → Copy MCP Token)
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
