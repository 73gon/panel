-- Migration: performance indexes + user preferences table

------------------------------------------------------------
-- UNIQUE INDEXES for upsert support on reading_progress
------------------------------------------------------------
-- Drop old non-unique indexes and recreate as unique
DROP INDEX IF EXISTS idx_progress_profile_book;
DROP INDEX IF EXISTS idx_progress_device_book;

CREATE UNIQUE INDEX IF NOT EXISTS idx_progress_profile_book
    ON reading_progress(profile_id, book_id) WHERE profile_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_progress_device_book
    ON reading_progress(device_id, book_id) WHERE profile_id IS NULL AND device_id IS NOT NULL;

------------------------------------------------------------
-- Missing index on books.path for scanner lookups
------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_books_path ON books(path);

------------------------------------------------------------
-- USER PREFERENCES (synced across devices)
------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_preferences (
    id              TEXT PRIMARY KEY,
    profile_id      TEXT REFERENCES profiles(id) ON DELETE CASCADE,
    device_id       TEXT REFERENCES devices(id) ON DELETE SET NULL,
    preferences     TEXT NOT NULL DEFAULT '{}',
    updated_at      TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(profile_id),
    UNIQUE(device_id)
);
