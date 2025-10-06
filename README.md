# Sora Engine

AI-powered video generation platform using OpenAI's Sora API.

## Repository Structure

```
sora-engine/
├── backend/          # Rust Cloudflare Worker (Production Ready ✅)
│   ├── src/         # Rust source code
│   ├── migrations/  # D1 database migrations
│   ├── docs/        # API documentation & landing page
│   └── README.md    # Backend documentation
└── ios/             # iOS App (Coming Soon)
```

## Quick Start

### Backend

The backend is **live and deployed** at:
```
https://sora-engine.guitaripod.workers.dev
```

See [`backend/DEPLOYMENT.md`](backend/DEPLOYMENT.md) for full deployment details.

To develop locally:
```bash
cd backend
cargo build
wrangler dev
```

### iOS App

Coming soon. Will be built with SwiftUI and integrate with:
- Sign in with Apple
- RevenueCat for in-app purchases
- Backend API for video generation

## Features

- **iOS-First**: Built for mobile with extensibility for web
- **Credit System**: $9.99 = 1,000 credits
- **Video Generation**: Sora-2 and Sora-2-Pro models
- **Authentication**: Sign in with Apple
- **Rate Limiting**: 20 videos/day per user
- **Webhooks**: Real-time OpenAI status updates

## Pricing

| Model | Duration | Credits | USD |
|-------|----------|---------|-----|
| sora-2 | 5s | 100 | $1.00 |
| sora-2 | 8s | 150 | $1.50 |
| sora-2-pro | 5s | 280 | $2.80 |
| sora-2-pro | 8s | 450 | $4.50 |

Starter Pack: **$9.99 = 1,000 credits** (10 videos with sora-2 5s)

## Architecture

- **Runtime**: Cloudflare Workers (Edge)
- **Language**: Rust (compiled to WASM)
- **Database**: Cloudflare D1 (SQLite)
- **API**: OpenAI Sora
- **Auth**: Apple Sign In
- **Payments**: RevenueCat (iOS IAP)

## Documentation

- [Backend README](backend/README.md) - Development guide
- [Deployment Guide](backend/DEPLOYMENT.md) - Production setup
- [API Docs](https://sora-engine.guitaripod.workers.dev/docs) - Swagger UI
- [OpenAPI Spec](https://sora-engine.guitaripod.workers.dev/openapi.yaml) - Full API spec

## License

MIT
