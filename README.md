# DROP

A fast, cross-platform note-taking app with voice recording and AI transcription.

## Features

- **Quick Capture**: Instantly save text, links, images, and files
- **Voice Recording**: Record voice memos with OpenAI Whisper transcription
- **Cross-Platform**: Mac (Electron) + iOS (SwiftUI)
- **Cloud Sync**: Real-time sync via Supabase
- **MCP Server**: Claude integration for AI-powered note management

## Apps

| Platform | Technology | Location |
|----------|------------|----------|
| Desktop (Mac) | Electron + React + TypeScript | `apps/desktop` |
| Mobile (iOS) | SwiftUI + Swift | `apps/ios` |
| MCP Server | Node.js + TypeScript | `packages/mcp-server` |

## Quick Start

### Prerequisites

- Node.js 20+
- pnpm 8+
- Xcode 16+ and XcodeGen (`brew install xcodegen`) — for iOS

### Setup

```bash
# Clone repository
git clone https://github.com/intelli-bruce/drop.git
cd drop

# Copy environment files
cp .env.example .env.local

# Install dependencies
pnpm install

# Start desktop app (local Supabase)
make electron-dev-local
```

### Environment Variables

Copy `.env.example` to `.env.local` and fill in the required values:

```bash
# Supabase (local)
SUPABASE_URL_LOCAL=http://127.0.0.1:57321
SUPABASE_ANON_KEY_LOCAL=<your-local-anon-key>

# Supabase (production)
SUPABASE_URL_REMOTE=<your-supabase-url>
SUPABASE_ANON_KEY_REMOTE=<your-supabase-anon-key>

# Google OAuth (for iOS login)
GOOGLE_WEB_CLIENT_ID=<your-web-client-id>
GOOGLE_IOS_CLIENT_ID=<your-ios-client-id>
```

## Development

### Desktop (Electron)

```bash
# Development
make electron-dev-local    # Local Supabase
make electron-dev-remote   # Remote Supabase

# Build
make electron-build-local
make electron-build-remote
```

### Mobile (iOS)

```bash
# Setup — env vars → Config-*.xcconfig (once)
make ios-config

# Test — domain logic, no simulator needed
make ios-test

# Development
make ios-dev               # Local Supabase
make ios-dev-remote        # Remote Supabase

# Build
make ios-build             # iOS Simulator
```

TestFlight builds go through CI: `gh workflow run release.yml -f target=ios`.
See [`apps/ios/README.md`](apps/ios/README.md) for structure and rules.

### MCP Server

```bash
cd packages/mcp-server
cp .env.example .env
# Fill in SUPABASE_URL and SUPABASE_ANON_KEY
pnpm build
pnpm start
```

## Project Structure

```
drop/
├── apps/
│   ├── desktop/          # Electron + React app
│   └── ios/              # SwiftUI iOS app (DropCore / DropUI packages)
├── packages/
│   ├── mcp-server/       # MCP server for Claude
│   └── shared/           # Shared types and utilities
├── supabase/
│   └── migrations/       # Database migrations
└── docs/                 # Documentation
```

## Documentation

- [Deployment Guide](docs/DEPLOYMENT.md)
- [Supabase Workflow](docs/SUPABASE_WORKFLOW.md)

## License

[MIT](LICENSE)
