use axum::extract::{Path, State};
use axum::http::{header, StatusCode};
use axum::response::{IntoResponse, Response};
use axum::Json;
use sha2::{Digest, Sha256};

use crate::error::AppError;
use crate::state::AppState;
use crate::zip::{content_type_for_entry, ZipIndex};

type PageRow = (String, String, String, String, i64, i64, i64, i32);
type PageManifestRow = (i32, String, i64, i64, Option<i32>, Option<i32>);

pub async fn page(
    State(state): State<AppState>,
    Path((book_id, page_num)): Path<(String, i32)>,
    req: axum::http::Request<axum::body::Body>,
) -> Result<Response, AppError> {
    // page_num is 1-indexed in API, 0-indexed internally
    let page_index = page_num - 1;

    if page_index < 0 {
        return Err(AppError::BadRequest("Page number must be >= 1".to_string()));
    }

    // Single query: book path + page entry data
    let row: Option<PageRow> = sqlx::query_as(
        "SELECT b.path, l.path, b.file_mtime,
                p.entry_name, p.entry_offset, p.compressed_size,
                p.uncompressed_size, p.compression
         FROM pages p
         JOIN books b ON p.book_id = b.id
         JOIN series s ON b.series_id = s.id
         JOIN libraries l ON s.library_id = l.id
         WHERE p.book_id = ? AND p.page_number = ?",
    )
    .bind(&book_id)
    .bind(page_index)
    .fetch_optional(&state.db)
    .await?;

    let (
        book_rel_path,
        lib_path,
        file_mtime,
        entry_name,
        entry_offset,
        compressed_size,
        uncompressed_size,
        compression,
    ) = row.ok_or_else(|| {
        AppError::NotFound(format!("Page {} not found for book {}", page_num, book_id))
    })?;

    let full_path = std::path::PathBuf::from(&lib_path).join(&book_rel_path);

    // Compute ETag
    let etag = compute_etag(&book_id, page_index, &file_mtime);

    // Check If-None-Match
    if let Some(inm) = req.headers().get(header::IF_NONE_MATCH) {
        if let Ok(inm_str) = inm.to_str() {
            let inm_clean = inm_str.trim_matches('"');
            if inm_clean == etag {
                return Ok(StatusCode::NOT_MODIFIED.into_response());
            }
        }
    }

    // Read page data using pre-indexed offsets
    let data = tokio::task::spawn_blocking({
        let path = full_path.clone();
        let entry = crate::zip::PageEntry {
            entry_name: entry_name.clone(),
            local_header_offset: entry_offset as u64,
            compressed_size: compressed_size as u64,
            uncompressed_size: uncompressed_size as u64,
            compression_method: compression as u16,
            crc32: 0,
        };
        move || ZipIndex::read_page_data(&path, &entry)
    })
    .await
    .map_err(|e| AppError::Internal(format!("Task join error: {}", e)))
    .and_then(|r| {
        r.map_err(|e| {
            tracing::error!("Failed to read page from {}: {}", full_path.display(), e);
            AppError::Internal(e.to_string())
        })
    })?;

    let content_type = content_type_for_entry(&entry_name);

    Ok((
        StatusCode::OK,
        [
            (header::CONTENT_TYPE, content_type.to_string()),
            (header::CONTENT_LENGTH, data.len().to_string()),
            (
                header::CACHE_CONTROL,
                "private, max-age=86400, immutable".to_string(),
            ),
            (header::ETAG, format!("\"{}\"", etag)),
        ],
        data,
    )
        .into_response())
}

fn compute_etag(book_id: &str, page_num: i32, mtime: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(book_id.as_bytes());
    hasher.update(page_num.to_le_bytes());
    hasher.update(mtime.as_bytes());
    let result = hasher.finalize();
    hex::encode(&result[..8])
}

/// Download the raw CBZ file for a book (for offline reading on iOS)
pub async fn download_book(
    State(state): State<AppState>,
    Path(book_id): Path<String>,
) -> Result<Response, AppError> {
    let row: Option<(String, String, String, i64)> = sqlx::query_as(
        "SELECT b.path, l.path, b.filename, b.file_size
         FROM books b
         JOIN series s ON b.series_id = s.id
         JOIN libraries l ON s.library_id = l.id
         WHERE b.id = ?",
    )
    .bind(&book_id)
    .fetch_optional(&state.db)
    .await?;

    let (book_rel_path, lib_path, filename, file_size) = row.ok_or_else(|| {
        AppError::NotFound(format!("Book {} not found", book_id))
    })?;

    let full_path = std::path::PathBuf::from(&lib_path).join(&book_rel_path);

    if !full_path.exists() {
        return Err(AppError::NotFound("Book file not found on disk".to_string()));
    }

    let data = tokio::fs::read(&full_path).await.map_err(|e| {
        tracing::error!("Failed to read book file {}: {}", full_path.display(), e);
        AppError::Internal(e.to_string())
    })?;

    Ok((
        StatusCode::OK,
        [
            (header::CONTENT_TYPE, "application/zip".to_string()),
            (header::CONTENT_LENGTH, file_size.to_string()),
            (
                header::CONTENT_DISPOSITION,
                format!("attachment; filename=\"{}\"", filename),
            ),
            (
                header::CACHE_CONTROL,
                "private, max-age=86400".to_string(),
            ),
        ],
        data,
    )
        .into_response())
}

/// Return a manifest of all pages for a book (dimensions, sizes)
pub async fn page_manifest(
    State(state): State<AppState>,
    Path(book_id): Path<String>,
) -> Result<Json<PageManifestResponse>, AppError> {
    let book: Option<(String, i32)> = sqlx::query_as(
        "SELECT id, page_count FROM books WHERE id = ?",
    )
    .bind(&book_id)
    .fetch_optional(&state.db)
    .await?;

    let (_, page_count) = book.ok_or_else(|| {
        AppError::NotFound(format!("Book {} not found", book_id))
    })?;

    let pages: Vec<PageManifestRow> = sqlx::query_as(
        "SELECT page_number, entry_name, compressed_size, uncompressed_size, width, height
         FROM pages WHERE book_id = ? ORDER BY page_number",
    )
    .bind(&book_id)
    .fetch_all(&state.db)
    .await?;

    let entries: Vec<PageManifestEntry> = pages
        .into_iter()
        .map(|(page_number, entry_name, compressed_size, uncompressed_size, width, height)| {
            PageManifestEntry {
                page: page_number + 1, // 1-indexed for API
                url: format!("/api/books/{}/pages/{}", book_id, page_number + 1),
                entry_name,
                compressed_size,
                uncompressed_size,
                width,
                height,
            }
        })
        .collect();

    Ok(Json(PageManifestResponse {
        book_id: book_id.clone(),
        page_count,
        pages: entries,
    }))
}

#[derive(serde::Serialize)]
pub struct PageManifestResponse {
    pub book_id: String,
    pub page_count: i32,
    pub pages: Vec<PageManifestEntry>,
}

#[derive(serde::Serialize)]
pub struct PageManifestEntry {
    pub page: i32,
    pub url: String,
    pub entry_name: String,
    pub compressed_size: i64,
    pub uncompressed_size: i64,
    pub width: Option<i32>,
    pub height: Option<i32>,
}
