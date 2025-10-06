# 🎬 Sora Engine

**Production-ready Cloudflare Worker backend for iOS AI video generation powered by OpenAI Sora**

## Features

- ⚡ **Blazing Fast**: Deployed on Cloudflare's edge network
- 📱 **iOS-First**: Sign in with Apple integration
- 💰 **Simple Pricing**: $9.99 for 1,000 credits
- 🎥 **Multiple Models**: sora-2 (fast) and sora-2-pro (premium)
- 🔒 **Secure**: Credit-based system with rate limiting
- 📊 **Production-Ready**: Full error handling, logging, and monitoring

## Tech Stack

- **Runtime**: Cloudflare Workers (Rust + WASM)
- **Database**: Cloudflare D1 (SQLite)
- **Authentication**: Sign in with Apple
- **Payments**: RevenueCat (iOS IAP)
- **Video API**: OpenAI Sora

## Quick Start

### Prerequisites

- Rust 1.70+
- wrangler CLI
- Cloudflare account

### Setup

```bash
# Install worker-build
cargo install worker-build

# Create D1 database
npx wrangler d1 create sora_engine

# Update wrangler.toml with the database_id

# Run migrations
npx wrangler d1 migrations apply sora_engine --local
npx wrangler d1 migrations apply sora_engine --remote

# Add secrets
echo "your-openai-api-key" | npx wrangler secret put OPENAI_API_KEY

# Development
npx wrangler dev

# Deploy
npx wrangler deploy
```

## API Endpoints

### Authentication
- `POST /v1/auth/apple/token` - Sign in with Apple
- `GET /v1/auth/me` - Get current user

### Video Generation
- `POST /v1/videos` - Create video
- `GET /v1/videos/:id` - Get video status
- `GET /v1/videos` - List videos
- `POST /v1/videos/estimate` - Estimate cost

### Credits
- `GET /v1/credits/balance` - Get balance
- `GET /v1/credits/transactions` - Transaction history
- `GET /v1/credits/packs` - Available packs
- `POST /v1/credits/purchase/revenuecat/validate` - Validate IAP

### Webhooks
- `POST /v1/webhook/openai` - OpenAI webhook

## Pricing

| Model | Duration | Credits | USD Equivalent |
|-------|----------|---------|----------------|
| sora-2 | 5s | 100 | $1.00 |
| sora-2 | 8s | 150 | $1.50 |
| sora-2-pro | 5s | 280 | $2.80 |
| sora-2-pro | 8s | 450 | $4.50 |

**Starter Pack**: $9.99 = 1,000 credits (~6-10 videos)

## Architecture

```
iOS App (SwiftUI)
    ↓
Sign in with Apple
    ↓
Cloudflare Worker (Rust)
    ├─ D1 Database (users, videos, credits)
    ├─ OpenAI Sora API
    └─ RevenueCat (IAP validation)
```

## Database Schema

- `users` - User accounts and credit balances
- `videos` - Video generation history
- `credit_transactions` - All credit movements
- `user_locks` - Prevent concurrent generations
- `webhook_events` - OpenAI webhook log

## Rate Limiting

- 20 videos per day per user (configurable)
- 1 concurrent generation per user

## Security

- Bcrypt password hashing (if email/password added)
- API key validation on all endpoints
- CORS enabled
- Webhook signature verification
- Rate limiting
- Input validation

## Environment Variables

```toml
ENVIRONMENT = "production"
SERVICE_URL = "https://sora-engine.yourname.workers.dev"
MAX_VIDEOS_PER_DAY = "20"
STARTER_PACK_CREDITS = "1000"
STARTER_PACK_PRICE_USD = "9.99"
APPLE_TEAM_ID = "YOUR_TEAM_ID"
APPLE_CLIENT_ID = "com.yourname.sora"
```

## Secrets (use wrangler secret put)

- `OPENAI_API_KEY` - OpenAI API key
- `APPLE_PRIVATE_KEY` - Apple private key for JWT (optional)
- `REVENUECAT_API_KEY` - RevenueCat API key (optional)
- `OPENAI_WEBHOOK_SECRET` - OpenAI webhook secret (optional)

## Development

```bash
# Run locally
npx wrangler dev

# Watch logs
npx wrangler tail

# Check D1 database
npx wrangler d1 execute sora_engine --command "SELECT * FROM users LIMIT 10"

# Build
cargo build --release
```

## Deployment

```bash
# Deploy to production
npx wrangler deploy

# Deploy to staging
npx wrangler deploy --env development
```

## License

MIT

## Credits

Built with:
- [Cloudflare Workers](https://workers.cloudflare.com/)
- [worker-rs](https://github.com/cloudflare/workers-rs)
- [OpenAI Sora](https://openai.com/sora)
