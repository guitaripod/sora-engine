# Sora Engine iOS App

iOS application for AI-powered video generation using OpenAI's Sora API.

## Coming Soon

This directory will contain the SwiftUI iOS app.

## Planned Features

- Sign in with Apple authentication
- Apple In-App Purchase for credit purchases
- Video generation interface
- Video gallery and playback
- Credit balance display
- Real-time generation progress

## Backend API

The app will integrate with the production backend:
```
https://sora-engine.guitaripod.workers.dev
```

See [API Documentation](https://sora-engine.guitaripod.workers.dev/docs) for available endpoints.

## Requirements

- iOS 15.0+
- Xcode 15.0+
- Apple Developer Account
- Sign in with Apple capability

## Setup Instructions

1. Create Xcode project with Bundle ID: `com.guitaripod.sora`
2. Enable Sign in with Apple capability
3. Configure Apple IAP with product ID: `sora_starter_pack`
4. Integrate with backend API endpoints

## Authentication Flow

```swift
// 1. Sign in with Apple
POST /v1/auth/apple/token
{ "identity_token": "..." }
→ { "user_id": "abc123", "credits_balance": 0 }

// 2. Store user_id for API calls
// 3. Use as Bearer token: "Authorization: Bearer abc123"
```

## Development

Coming soon.
