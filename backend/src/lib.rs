use worker::*;

mod models;
mod error;
mod auth;
mod pricing;
mod db;
mod credits;
mod openai_client;
mod rate_limit;
mod handlers;

use error::AppError;

fn cors_headers() -> Headers {
    let headers = Headers::new();
    let _ = headers.set("Access-Control-Allow-Origin", "*");
    let _ = headers.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    let _ = headers.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
    let _ = headers.set("Access-Control-Max-Age", "86400");
    headers
}

#[event(fetch)]
async fn main(req: Request, env: Env, _ctx: Context) -> worker::Result<Response> {
    console_error_panic_hook::set_once();

    let router = Router::new();

    let result = router
        .get("/", |_, _| {
            let html = include_str!("../docs/index.html");
            Response::from_html(html)
        })
        .get("/docs", |_, _| {
            let html = include_str!("../docs/swagger-ui.html");
            Response::from_html(html)
        })
        .get("/openapi.yaml", |_, _| {
            let yaml = include_str!("../openapi.yaml");
            Response::ok(yaml).map(|mut r| {
                r.headers_mut().set("Content-Type", "application/yaml").unwrap();
                r
            })
        })
        .get("/privacy-policy", |_, _| {
            let html = include_str!("../docs/privacy-policy.html");
            Response::from_html(html)
        })
        .get("/health", |_, _| Response::ok("OK"))
        .post_async("/v1/auth/apple/token", handlers::auth::apple_sign_in)
        .get_async("/v1/auth/me", handlers::auth::get_me)
        .post_async("/v1/videos", handlers::videos::create_video)
        .get_async("/v1/videos/:id", handlers::videos::get_video)
        .get_async("/v1/videos", handlers::videos::list_videos)
        .post_async("/v1/videos/estimate", handlers::videos::estimate_cost)
        .get_async("/v1/credits/balance", handlers::credits::get_balance)
        .get_async("/v1/credits/transactions", handlers::credits::get_transactions)
        .get_async("/v1/credits/packs", handlers::credits::get_credit_packs)
        .post_async(
            "/v1/credits/purchase/revenuecat/validate",
            handlers::credits::validate_revenuecat_purchase,
        )
        .post_async("/v1/webhook/openai", handlers::webhooks::openai_webhook)
        .options("/*catchall", |_, _| {
            Response::ok("").map(|r| r.with_headers(cors_headers()))
        })
        .run(req, env)
        .await;

    match result {
        Ok(response) => Ok(response),
        Err(e) => {
            console_error!("Router error: {:?}", e);

            let app_error = AppError::InternalError(e.to_string());
            app_error.to_response().or_else(|_| {
                Response::error("Internal Server Error", 500)
            })
        }
    }
}
