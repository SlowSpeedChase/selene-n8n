-- Migration 008: Classification Fields for Phase 7.1
-- Created: 2025-12-30
-- Phase: 7.1 - Task Extraction with Classification
--
-- Purpose: Add classification logic to support intelligent note triage:
--   - actionable: Clear tasks routed to Things inbox
--   - needs_planning: Goals/projects flagged for SeleneChat planning sessions
--   - archive_only: Thoughts/reflections stored for Obsidian export
--
-- Related: docs/architecture/metadata-definitions.md
--          docs/plans/2025-12-30-task-extraction-planning-design.md

-- ============================================================================
-- COLUMNS: processed_notes table extensions
-- ============================================================================

-- Add classification column to processed_notes
-- Determines routing: actionable -> Things, needs_planning -> SeleneChat, archive_only -> Obsidian
ALTER TABLE processed_notes ADD COLUMN classification TEXT
    DEFAULT 'archive_only'
    CHECK(classification IN ('actionable', 'needs_planning', 'archive_only'));

-- Add planning_status column to processed_notes
-- Tracks lifecycle of needs_planning items through SeleneChat
-- NULL = not applicable (actionable or archive_only items)
ALTER TABLE processed_notes ADD COLUMN planning_status TEXT
    DEFAULT NULL
    CHECK(planning_status IS NULL OR planning_status IN ('pending_review', 'in_planning', 'planned', 'archived'));

-- ============================================================================
-- TABLE: discussion_threads
-- ============================================================================
-- Stores discussion threads for SeleneChat to continue conversations
-- Phase 7.2 will use this for "Threads to Continue" feature

CREATE TABLE IF NOT EXISTS discussion_threads (
    id INTEGER PRIMARY KEY AUTOINCREMENT,

    -- Link to source note
    raw_note_id INTEGER NOT NULL,

    -- Thread metadata
    thread_type TEXT NOT NULL
        CHECK(thread_type IN ('planning', 'followup', 'question')),

    -- The prompt to surface in SeleneChat
    prompt TEXT NOT NULL,

    -- Thread lifecycle
    status TEXT DEFAULT 'pending'
        CHECK(status IN ('pending', 'active', 'completed', 'dismissed')),

    -- Timestamps
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    surfaced_at TEXT,       -- When thread was shown to user
    completed_at TEXT,      -- When user finished/dismissed thread

    -- Contextual data for matching related topics
    related_concepts TEXT,  -- JSON array of concept strings

    -- Test data isolation
    test_run TEXT DEFAULT NULL,

    -- Referential integrity
    FOREIGN KEY (raw_note_id) REFERENCES raw_notes(id) ON DELETE CASCADE
);

-- ============================================================================
-- INDEXES: Performance optimization
-- ============================================================================

-- Index for querying notes by classification
-- Used by: workflow routing, SeleneChat queries
CREATE INDEX IF NOT EXISTS idx_processed_notes_classification
    ON processed_notes(classification);

-- Index for querying needs_planning items by status
-- Used by: SeleneChat "Threads to Continue" feature
CREATE INDEX IF NOT EXISTS idx_processed_notes_planning_status
    ON processed_notes(planning_status);

-- Index for querying pending/active threads
-- Used by: SeleneChat to show threads that need attention
CREATE INDEX IF NOT EXISTS idx_discussion_threads_status
    ON discussion_threads(status);

-- Index for finding threads by source note
-- Used by: Joining with note data in SeleneChat
CREATE INDEX IF NOT EXISTS idx_discussion_threads_raw_note_id
    ON discussion_threads(raw_note_id);

-- Index for test data cleanup
-- Used by: ./scripts/cleanup-tests.sh
CREATE INDEX IF NOT EXISTS idx_discussion_threads_test_run
    ON discussion_threads(test_run);

-- ============================================================================
-- VERIFICATION QUERIES (run after migration)
-- ============================================================================
-- sqlite3 data/selene.db "PRAGMA table_info(processed_notes);"
-- sqlite3 data/selene.db ".schema discussion_threads"
-- sqlite3 data/selene.db "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name IN ('processed_notes', 'discussion_threads');"
