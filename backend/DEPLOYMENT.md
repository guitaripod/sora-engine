# 🚀 SORA-ENGINE DEPLOYMENT GUIDE

## ✅ Deployed Successfully!

**Production URL**: https://sora-engine.guitaripod.workers.dev

## 📊 Deployment Summary

- **Worker Name**: sora-engine
- **Version ID**: 5cfa2461-95cc-474c-ab67-2c0ff0288056
- **Total Upload Size**: 621.45 KiB (gzip: 249.76 KiB)
- **Worker Startup Time**: 1 ms
- **Database**: D1 (sora_engine) - Migrations applied ✅
- **API Key**: OpenAI key configured ✅

## 🔗 Live Endpoints

### Public Endpoints
- **Landing Page**: https://sora-engine.guitaripod.workers.dev/
- **API Documentation**: https://sora-engine.guitaripod.workers.dev/docs
- **OpenAPI Spec**: https://sora-engine.guitaripod.workers.dev/openapi.yaml
- **Privacy Policy**: https://sora-engine.guitaripod.workers.dev/privacy-policy
- **Health Check**: https://sora-engine.guitaripod.workers.dev/health

### Authentication
- `POST /v1/auth/apple/token` - Sign in with Apple
- `GET /v1/auth/me` - Get current user

### Video Generation
- `POST /v1/videos` - Create video
- `GET /v1/videos/:id` - Get video status
- `GET /v1/videos` - List user's videos
- `POST /v1/videos/estimate` - Estimate credits

### Credits
- `GET /v1/credits/balance` - Get balance
- `GET /v1/credits/transactions` - Get transactions
- `GET /v1/credits/packs` - Get available packs
- `POST /v1/credits/purchase/revenuecat/validate` - Validate iOS purchase

### Webhooks
- `POST /v1/webhook/openai` - OpenAI completion webhook

## 🔒 Configured Secrets

✅ `OPENAI_API_KEY` - Configured and working

## ⚙️ Environment Variables

| Variable | Value |
|----------|-------|
| ENVIRONMENT | production |
| SERVICE_URL | https://sora-engine.guitaripod.workers.dev |
| MAX_VIDEOS_PER_DAY | 20 |
| STARTER_PACK_CREDITS | 1000 |
| STARTER_PACK_PRICE_USD | 9.99 |
| APPLE_TEAM_ID | P4DQK6SRKR |
| APPLE_CLIENT_ID | com.guitaripod.sora |

## 📦 Credit Pack Pricing

**Starter Pack**: $9.99 = 1,000 credits

### Video Generation Costs:
- **sora-2 (5s)**: 100 credits ($1.00)
- **sora-2 (8s)**: 150 credits ($1.50)
- **sora-2-pro (5s)**: 280 credits ($2.80)
- **sora-2-pro (8s)**: 450 credits ($4.50)

## 🎯 Next Steps for iOS App

### 1. Configure Apple Sign In
Your iOS app needs to:
- Use `com.guitaripod.sora` as the client ID
- Send the identity token to `POST /v1/auth/apple/token`
- Store the returned `user_id` as the Bearer token

### 2. Configure RevenueCat
- Product ID: `sora_starter_pack`
- Price: $9.99
- Credits: 1,000

### 3. Test Video Generation Flow

```swift
// 1. Sign in with Apple
POST /v1/auth/apple/token
{
  "identity_token": "..."
}
// Response: { "user_id": "abc123", "credits_balance": 0, "created": true }

// 2. Purchase credits (via RevenueCat)
POST /v1/credits/purchase/revenuecat/validate
Headers: Authorization: Bearer abc123
{
  "transaction_id": "...",
  "product_id": "sora_starter_pack",
  "receipt_data": "..."
}
// Response: { "success": true, "credits_added": 1000, "new_balance": 1000 }

// 3. Estimate cost
POST /v1/videos/estimate
Headers: Authorization: Bearer abc123
{
  "model": "sora-2",
  "size": "720x1280",
  "seconds": 5
}
// Response: { "credits_cost": 100, "current_balance": 1000, "sufficient_credits": true }

// 4. Create video
POST /v1/videos
Headers: Authorization: Bearer abc123
{
  "model": "sora-2",
  "prompt": "A serene beach at sunset with gentle waves",
  "size": "720x1280",
  "seconds": 5
}
// Response: { "id": "video_123", "status": "queued", "credits_cost": 100, "new_balance": 900 }

// 5. Poll status (every 5 seconds)
GET /v1/videos/video_123
Headers: Authorization: Bearer abc123
// Response: { "status": "in_progress", "progress": 45 }

// 6. When completed
// Response: {
//   "status": "completed",
//   "video_url": "https://api.openai.com/v1/videos/...",
//   "thumbnail_url": "...",
//   "download_url_expires_at": "2025-10-08T12:00:00Z"
// }
```

## 🔔 Configure OpenAI Webhook (Optional)

Register webhook URL with OpenAI to get real-time status updates:
```
https://sora-engine.guitaripod.workers.dev/v1/webhook/openai
```

This will automatically update video status and refund credits on failures.

## 📈 Monitoring

### View Logs:
```bash
wrangler tail
```

### Check Database:
```bash
wrangler d1 execute sora_engine --command "SELECT * FROM users LIMIT 10"
wrangler d1 execute sora_engine --command "SELECT * FROM videos ORDER BY created_at DESC LIMIT 10"
```

### Update Secrets:
```bash
echo "new-api-key" | wrangler secret put OPENAI_API_KEY
```

## 🚨 Rate Limits

- **20 videos per day** per user (configurable via MAX_VIDEOS_PER_DAY)
- **1 concurrent generation** per user (enforced via locks)

## ⚡ Performance

- **Cold Start**: 1ms
- **Edge Deployment**: Global via Cloudflare
- **Database**: D1 (SQLite at the edge)
- **Caching**: Automatic via Cloudflare

## 🔐 Security Features

✅ Apple Sign In with JWT validation
✅ API key-based auth (user_id as Bearer token)
✅ Credit system with atomic operations
✅ User locks prevent concurrent generations
✅ Rate limiting (20/day)
✅ Input validation on all endpoints
✅ CORS enabled

## 📊 Business Metrics to Track

Once iOS app is live, monitor:
- Daily active users (DAUs)
- Purchase conversion rate
- Average videos per user
- Revenue per user
- Credit pack purchases
- OpenAI API costs
- Profit margins

## 🎉 What's Working

✅ Production Cloudflare Worker deployed
✅ D1 Database created and migrated
✅ OpenAI API key configured
✅ All API endpoints live
✅ Swagger documentation accessible
✅ Credit system ready
✅ Rate limiting active
✅ Webhook handler ready

## 📱 Ready for iOS Integration!

Your backend is **production-ready**. Build the iOS app and start generating videos! 🚀
