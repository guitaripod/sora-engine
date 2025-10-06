# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Sora Engine is an AI-powered video generation platform using OpenAI's Sora API. The project consists of two main components:

1. **Backend**: Rust-based Cloudflare Worker providing REST API for video generation, authentication, and credit management
2. **iOS App**: Native iOS application with Sign in with Apple and RevenueCat integration

## Backend (Cloudflare Worker)

### Location
`backend/` - Rust Cloudflare Worker compiled to WASM

### Build and Deploy Commands

Build the worker:
```bash
cd backend
cargo build --release
```

Deploy to production:
```bash
cd backend
wrangler deploy
```

Run locally:
```bash
cd backend
wrangler dev
```

View logs:
```bash
cd backend
wrangler tail
```

Database operations:
```bash
cd backend
wrangler d1 execute sora_engine --command "SELECT * FROM users LIMIT 10"
wrangler d1 execute sora_engine --command "SELECT * FROM videos ORDER BY created_at DESC LIMIT 10"
```

### Architecture Notes

- **Runtime**: Cloudflare Workers (Edge computing platform)
- **Language**: Rust compiled to WebAssembly
- **Database**: Cloudflare D1 (distributed SQLite)
- **Build Tool**: worker-build (compiles Rust → WASM → shim.mjs)
- **Entry Point**: `src/lib.rs` with `#[event(fetch)]` macro
- **Router**: worker::Router for endpoint routing
- **Error Handling**: Custom AppError enum with `to_response()` conversion

### Key Patterns

- **Handler Pattern**: Inner function returns `Result<Response, AppError>`, public function wraps with `.or_else(|e| e.to_response())`
- **Credit System**: Atomic operations with user locks to prevent race conditions
- **Authentication**: JWT validation for Apple Sign In tokens
- **Rate Limiting**: 20 videos/day per user, 1 concurrent generation
- **Webhooks**: OpenAI webhook integration for status updates and auto-refunds

### Dependencies

Key crates:
- `worker` - Cloudflare Workers runtime with D1 support
- `serde` - JSON serialization
- `chrono` - Datetime handling
- `uuid` - ID generation
- `jwt-simple` - JWT validation
- `base64` - Token decoding (use Engine trait API)

### Production URL
https://sora-engine.guitaripod.workers.dev

### Secrets Management
Never commit secrets. Use wrangler for secret management:
```bash
echo "secret-value" | wrangler secret put SECRET_NAME
```

Configured secrets:
- `OPENAI_API_KEY` - OpenAI API key for Sora video generation

## iOS App

### Location
`ios/sora/` - Native iOS application

### Build and Run Commands

Build the project:
```bash
cd ios/sora
xcodebuild -project sora.xcodeproj -scheme sora -configuration Debug build
```

Build for simulator:
```bash
cd ios/sora
xcodebuild -project sora.xcodeproj -scheme sora -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build
```

Clean build:
```bash
cd ios/sora
xcodebuild -project sora.xcodeproj -scheme sora clean
```

### Architecture Notes

- **UI Framework**: UIKit (no Storyboards) - programmatic UI only
- **Minimum iOS Version**: iOS 17.0+
- **Supported Devices**: iPhone only
- **Bundle ID**: com.guitaripod.sora
- **Team ID**: P4DQK6SRKR
- **Authentication**: Sign in with Apple
- **Payments**: RevenueCat for in-app purchases
- **Networking**: URLSession for backend API calls

### Coding Practices

- Follow programmatic UI approach - no Interface Builder
- Use UIStackView heavily for layout
- Use latest UIKit APIs (diffable data sources, compositional layouts)
- Prefer Protocol-Oriented Programming over Object-Oriented Programming
- Use structured logging - never use `print()` statements
- **swift-format**: Always run swift-format before committing

### Backend Integration

The iOS app integrates with the production backend API:
```
https://sora-engine.guitaripod.workers.dev
```

Authentication flow:
1. Sign in with Apple → get identity token
2. Send token to `POST /v1/auth/apple/token`
3. Store returned `user_id` as Bearer token
4. Use for all subsequent API calls: `Authorization: Bearer {user_id}`

Key endpoints:
- `POST /v1/auth/apple/token` - Authenticate with Apple
- `POST /v1/videos` - Create video generation
- `GET /v1/videos/:id` - Get video status
- `GET /v1/credits/balance` - Get credit balance
- `POST /v1/credits/purchase/revenuecat/validate` - Validate purchase

### RevenueCat Configuration

Product ID: `sora_starter_pack`
Price: $9.99
Credits: 1,000

## Pricing Model

| Model | Duration | Credits | USD | OpenAI Cost | Margin |
|-------|----------|---------|-----|-------------|--------|
| sora-2 | 4s | 100 | $1.00 | $0.50 | 100% |
| sora-2 | 8s | 150 | $1.50 | $0.80 | 88% |
| sora-2 | 12s | 200 | $2.00 | $1.10 | 82% |
| sora-2-pro | 4s | 280 | $2.80 | $1.50 | 87% |
| sora-2-pro | 8s | 450 | $4.50 | $2.40 | 88% |
| sora-2-pro | 12s | 560 | $5.60 | $3.00 | 87% |

Starter Pack: **$9.99 = 1,000 credits** (10 videos with sora-2 4s)
Welcome Bonus: **100 credits** (1 free video with sora-2 4s)

## Repository Structure

```
sora-engine/
├── backend/              # Rust Cloudflare Worker
│   ├── src/             # Rust source code
│   ├── migrations/      # D1 database migrations
│   ├── docs/            # API documentation
│   ├── Cargo.toml       # Rust dependencies
│   └── wrangler.toml    # Cloudflare config
└── ios/                 # iOS application
    └── sora/            # Xcode project
```

## Git Workflow

- Atomic commits per feature/fix
- Clear commit messages describing changes
- Never commit secrets or API keys
- Run tests before pushing (when available)

## Documentation

- [Backend README](backend/README.md) - Backend development guide
- [Deployment Guide](backend/DEPLOYMENT.md) - Production deployment
- [API Docs](https://sora-engine.guitaripod.workers.dev/docs) - Swagger UI
- [OpenAPI Spec](https://sora-engine.guitaripod.workers.dev/openapi.yaml) - Full API specification
