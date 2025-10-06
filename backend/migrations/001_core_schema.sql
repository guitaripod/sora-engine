CREATE TABLE users (
    id TEXT PRIMARY KEY,
    apple_user_id TEXT UNIQUE NOT NULL,
    email TEXT,
    credits_balance INTEGER NOT NULL DEFAULT 0,
    total_videos_generated INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_users_apple ON users(apple_user_id);

CREATE TABLE videos (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    openai_video_id TEXT UNIQUE NOT NULL,
    status TEXT NOT NULL DEFAULT 'queued',
    model TEXT NOT NULL,
    prompt TEXT NOT NULL,
    size TEXT NOT NULL,
    seconds INTEGER NOT NULL,
    video_url TEXT,
    thumbnail_url TEXT,
    spritesheet_url TEXT,
    download_url_expires_at TEXT,
    credits_cost INTEGER NOT NULL,
    progress INTEGER DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    completed_at TEXT,
    failed_at TEXT,
    error_message TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
CREATE INDEX idx_videos_user ON videos(user_id, created_at DESC);
CREATE INDEX idx_videos_openai ON videos(openai_video_id);
CREATE INDEX idx_videos_status ON videos(status);

CREATE TABLE credit_transactions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    amount INTEGER NOT NULL,
    balance_after INTEGER NOT NULL,
    transaction_type TEXT NOT NULL,
    description TEXT NOT NULL,
    video_id TEXT,
    revenuecat_transaction_id TEXT,
    metadata TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (video_id) REFERENCES videos(id) ON DELETE SET NULL
);
CREATE INDEX idx_transactions_user ON credit_transactions(user_id, created_at DESC);
CREATE INDEX idx_transactions_revenuecat ON credit_transactions(revenuecat_transaction_id);

CREATE TABLE user_locks (
    user_id TEXT PRIMARY KEY,
    video_id TEXT NOT NULL,
    locked_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (video_id) REFERENCES videos(id) ON DELETE CASCADE
);

CREATE TABLE webhook_events (
    id TEXT PRIMARY KEY,
    event_type TEXT NOT NULL,
    openai_video_id TEXT,
    payload TEXT NOT NULL,
    processed BOOLEAN DEFAULT 0,
    processed_at TEXT,
    error_message TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX idx_webhooks_processed ON webhook_events(processed, created_at);
CREATE INDEX idx_webhooks_video ON webhook_events(openai_video_id);
