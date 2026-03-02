use axum::extract::{Query, State};
use axum::http::header::HeaderMap;
use axum::http::StatusCode;
use axum::Json;
use serde::{Deserialize, Serialize};

use crate::error::AppError;
use crate::state::AppState;

#[derive(Deserialize)]
pub struct ProgressQuery {
    pub book_id: String,
}

#[derive(Serialize)]
pub struct ProgressResponse {
    pub book_id: String,
    pub page: i32,
    pub is_completed: bool,
    pub updated_at: String,
}

pub async fn get_progress(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<ProgressQuery>,
) -> Result<Json<Option<ProgressResponse>>, AppError> {
    let profile_id = extract_profile_id(&state, &headers).await;
    let device_id = extract_device_id(&state, &headers).await;

    // Try profile progress first, then device
    let row: Option<(String, i32, i32, String)> = if let Some(pid) = &profile_id {
        sqlx::query_as(
            "SELECT book_id, page_number, is_completed, updated_at
             FROM reading_progress WHERE profile_id = ? AND book_id = ?",
        )
        .bind(pid)
        .bind(&query.book_id)
        .fetch_optional(&state.db)
        .await?
    } else if let Some(did) = &device_id {
        sqlx::query_as(
            "SELECT book_id, page_number, is_completed, updated_at
             FROM reading_progress WHERE device_id = ? AND book_id = ? AND profile_id IS NULL",
        )
        .bind(did)
        .bind(&query.book_id)
        .fetch_optional(&state.db)
        .await?
    } else {
        None
    };

    let progress = row.map(|(book_id, page, is_completed, updated_at)| ProgressResponse {
        book_id,
        page: page + 1, // Convert to 1-indexed
        is_completed: is_completed != 0,
        updated_at,
    });

    Ok(Json(progress))
}

#[derive(Deserialize)]
pub struct UpdateProgressRequest {
    pub book_id: String,
    pub page: i32,
    pub is_completed: Option<bool>,
}

pub async fn update_progress(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<UpdateProgressRequest>,
) -> Result<StatusCode, AppError> {
    let profile_id = extract_profile_id(&state, &headers).await;
    let device_id = extract_device_id(&state, &headers).await;

    // Verify book exists
    let _: (String,) = sqlx::query_as("SELECT id FROM books WHERE id = ?")
        .bind(&body.book_id)
        .fetch_optional(&state.db)
        .await?
        .ok_or_else(|| AppError::NotFound("Book not found".to_string()))?;

    let page_internal = (body.page - 1).max(0); // Convert to 0-indexed
    let completed = body.is_completed.unwrap_or(false) as i32;
    let now = chrono::Utc::now().to_rfc3339();

    if let Some(pid) = &profile_id {
        // Upsert profile progress using ON CONFLICT
        let id = uuid::Uuid::new_v4().to_string();
        sqlx::query(
            "INSERT INTO reading_progress (id, profile_id, book_id, page_number, is_completed, updated_at)
             VALUES (?, ?, ?, ?, ?, ?)
             ON CONFLICT(profile_id, book_id) WHERE profile_id IS NOT NULL
             DO UPDATE SET page_number = excluded.page_number,
                           is_completed = excluded.is_completed,
                           updated_at = excluded.updated_at",
        )
        .bind(&id)
        .bind(pid)
        .bind(&body.book_id)
        .bind(page_internal)
        .bind(completed)
        .bind(&now)
        .execute(&state.db)
        .await?;
    } else if let Some(did) = &device_id {
        // Upsert device progress using ON CONFLICT
        let id = uuid::Uuid::new_v4().to_string();
        sqlx::query(
            "INSERT INTO reading_progress (id, device_id, book_id, page_number, is_completed, updated_at)
             VALUES (?, ?, ?, ?, ?, ?)
             ON CONFLICT(device_id, book_id) WHERE profile_id IS NULL AND device_id IS NOT NULL
             DO UPDATE SET page_number = excluded.page_number,
                           is_completed = excluded.is_completed,
                           updated_at = excluded.updated_at",
        )
        .bind(&id)
        .bind(did)
        .bind(&body.book_id)
        .bind(page_internal)
        .bind(completed)
        .bind(&now)
        .execute(&state.db)
        .await?;
    } else {
        return Err(AppError::BadRequest(
            "Either a profile session or X-Device-Id header is required".to_string(),
        ));
    }

    Ok(StatusCode::NO_CONTENT)
}

pub async fn migrate_progress(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<StatusCode, AppError> {
    let profile_id = extract_profile_id(&state, &headers)
        .await
        .ok_or(AppError::Unauthorized)?;
    let device_id = extract_device_id(&state, &headers)
        .await
        .ok_or_else(|| AppError::BadRequest("X-Device-Id header required".to_string()))?;

    let now = chrono::Utc::now().to_rfc3339();

    // Get all device-local progress
    let device_progress: Vec<(String, String, i32, i32, String)> = sqlx::query_as(
        "SELECT id, book_id, page_number, is_completed, updated_at
         FROM reading_progress WHERE device_id = ? AND profile_id IS NULL",
    )
    .bind(&device_id)
    .fetch_all(&state.db)
    .await?;

    for (dp_id, book_id, page_number, is_completed, updated_at) in device_progress {
        // Check if profile already has progress for this book
        let existing: Option<(String, String)> = sqlx::query_as(
            "SELECT id, updated_at FROM reading_progress WHERE profile_id = ? AND book_id = ?",
        )
        .bind(&profile_id)
        .bind(&book_id)
        .fetch_optional(&state.db)
        .await?;

        if let Some((existing_id, existing_updated)) = existing {
            // Keep the more recent one
            if updated_at > existing_updated {
                sqlx::query(
                    "UPDATE reading_progress SET page_number = ?, is_completed = ?, updated_at = ? WHERE id = ?",
                )
                .bind(page_number)
                .bind(is_completed)
                .bind(&now)
                .bind(&existing_id)
                .execute(&state.db)
                .await?;
            }
        } else {
            // Move device progress to profile
            sqlx::query(
                "UPDATE reading_progress SET profile_id = ?, updated_at = ? WHERE id = ?",
            )
            .bind(&profile_id)
            .bind(&now)
            .bind(&dp_id)
            .execute(&state.db)
            .await?;
        }

        // Delete the device-local entry
        sqlx::query("DELETE FROM reading_progress WHERE id = ? AND profile_id IS NULL")
            .bind(&dp_id)
            .execute(&state.db)
            .await?;
    }

    Ok(StatusCode::NO_CONTENT)
}

// ── Batch progress ──

#[derive(Deserialize)]
pub struct BatchProgressQuery {
    pub book_ids: String, // comma-separated
}

#[derive(Serialize)]
pub struct BatchProgressResponse {
    pub progress: std::collections::HashMap<String, ProgressResponse>,
}

pub async fn batch_progress(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<BatchProgressQuery>,
) -> Result<Json<BatchProgressResponse>, AppError> {
    let profile_id = extract_profile_id(&state, &headers).await;
    let device_id = extract_device_id(&state, &headers).await;

    let book_ids: Vec<&str> = query.book_ids.split(',').map(|s| s.trim()).filter(|s| !s.is_empty()).collect();
    let mut progress_map = std::collections::HashMap::new();

    for book_id in &book_ids {
        let row: Option<(String, i32, i32, String)> = if let Some(pid) = &profile_id {
            sqlx::query_as(
                "SELECT book_id, page_number, is_completed, updated_at
                 FROM reading_progress WHERE profile_id = ? AND book_id = ?",
            )
            .bind(pid)
            .bind(book_id)
            .fetch_optional(&state.db)
            .await?
        } else if let Some(did) = &device_id {
            sqlx::query_as(
                "SELECT book_id, page_number, is_completed, updated_at
                 FROM reading_progress WHERE device_id = ? AND book_id = ? AND profile_id IS NULL",
            )
            .bind(did)
            .bind(book_id)
            .fetch_optional(&state.db)
            .await?
        } else {
            None
        };

        if let Some((bid, page, is_completed, updated_at)) = row {
            progress_map.insert(bid.clone(), ProgressResponse {
                book_id: bid,
                page: page + 1,
                is_completed: is_completed != 0,
                updated_at,
            });
        }
    }

    Ok(Json(BatchProgressResponse { progress: progress_map }))
}

// ── Helpers ──

async fn extract_profile_id(state: &AppState, headers: &HeaderMap) -> Option<String> {
    let auth = headers.get("authorization")?.to_str().ok()?;
    let token = auth.strip_prefix("Bearer ")?;

    let row: Option<(String, String)> = sqlx::query_as(
        "SELECT profile_id, expires_at FROM sessions WHERE token = ?",
    )
    .bind(token)
    .fetch_optional(&state.db)
    .await
    .ok()?;

    let (profile_id, expires_at) = row?;
    // Check expiry
    if let Ok(exp) = chrono::DateTime::parse_from_rfc3339(&expires_at) {
        if exp < chrono::Utc::now() {
            return None;
        }
    }

    Some(profile_id)
}

async fn extract_device_id(state: &AppState, headers: &HeaderMap) -> Option<String> {
    let fingerprint = headers.get("x-device-id")?.to_str().ok()?;

    // Ensure device record exists
    let existing: Option<(String,)> =
        sqlx::query_as("SELECT id FROM devices WHERE device_fingerprint = ?")
            .bind(fingerprint)
            .fetch_optional(&state.db)
            .await
            .ok()?;

    if let Some((id,)) = existing {
        // Update last_seen
        let _ = sqlx::query("UPDATE devices SET last_seen_at = datetime('now') WHERE id = ?")
            .bind(&id)
            .execute(&state.db)
            .await;
        Some(id)
    } else {
        let id = uuid::Uuid::new_v4().to_string();
        let _ = sqlx::query(
            "INSERT INTO devices (id, device_fingerprint) VALUES (?, ?)",
        )
        .bind(&id)
        .bind(fingerprint)
        .execute(&state.db)
        .await;
        Some(id)
    }
}

// ── Preferences ──

#[derive(Serialize)]
pub struct PreferencesResponse {
    pub preferences: serde_json::Value,
}

pub async fn get_preferences(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<PreferencesResponse>, AppError> {
    let profile_id = extract_profile_id(&state, &headers).await;
    let device_id = extract_device_id(&state, &headers).await;

    let row: Option<(String,)> = if let Some(pid) = &profile_id {
        sqlx::query_as("SELECT preferences FROM user_preferences WHERE profile_id = ?")
            .bind(pid)
            .fetch_optional(&state.db)
            .await?
    } else if let Some(did) = &device_id {
        sqlx::query_as("SELECT preferences FROM user_preferences WHERE device_id = ? AND profile_id IS NULL")
            .bind(did)
            .fetch_optional(&state.db)
            .await?
    } else {
        None
    };

    let prefs = row
        .and_then(|(json_str,)| serde_json::from_str(&json_str).ok())
        .unwrap_or(serde_json::json!({}));

    Ok(Json(PreferencesResponse { preferences: prefs }))
}

#[derive(Deserialize)]
pub struct UpdatePreferencesRequest {
    pub preferences: serde_json::Value,
}

pub async fn update_preferences(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<UpdatePreferencesRequest>,
) -> Result<StatusCode, AppError> {
    let profile_id = extract_profile_id(&state, &headers).await;
    let device_id = extract_device_id(&state, &headers).await;
    let now = chrono::Utc::now().to_rfc3339();
    let prefs_json = serde_json::to_string(&body.preferences)
        .map_err(|e| AppError::BadRequest(format!("Invalid JSON: {}", e)))?;

    if let Some(pid) = &profile_id {
        let id = uuid::Uuid::new_v4().to_string();
        sqlx::query(
            "INSERT INTO user_preferences (id, profile_id, preferences, updated_at)
             VALUES (?, ?, ?, ?)
             ON CONFLICT(profile_id) DO UPDATE SET preferences = excluded.preferences, updated_at = excluded.updated_at",
        )
        .bind(&id)
        .bind(pid)
        .bind(&prefs_json)
        .bind(&now)
        .execute(&state.db)
        .await?;
    } else if let Some(did) = &device_id {
        let id = uuid::Uuid::new_v4().to_string();
        sqlx::query(
            "INSERT INTO user_preferences (id, device_id, preferences, updated_at)
             VALUES (?, ?, ?, ?)
             ON CONFLICT(device_id) DO UPDATE SET preferences = excluded.preferences, updated_at = excluded.updated_at",
        )
        .bind(&id)
        .bind(did)
        .bind(&prefs_json)
        .bind(&now)
        .execute(&state.db)
        .await?;
    } else {
        return Err(AppError::BadRequest(
            "Either a profile session or X-Device-Id header is required".to_string(),
        ));
    }

    Ok(StatusCode::NO_CONTENT)
}
