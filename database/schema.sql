CREATE TABLE test_table (id INTEGER PRIMARY KEY, name TEXT, created_at DATETIME DEFAULT CURRENT_TIMESTAMP);
CREATE TABLE raw_notes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    content_hash TEXT UNIQUE NOT NULL,
    source_type TEXT DEFAULT 'drafts',
    word_count INTEGER DEFAULT 0,
    character_count INTEGER DEFAULT 0,
    tags TEXT, -- JSON array of tags
    created_at DATETIME NOT NULL,
    imported_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    processed_at DATETIME,
    exported_at DATETIME,
    status TEXT DEFAULT 'pending', -- pending, processed, archived
    exported_to_obsidian INTEGER DEFAULT 0
);
CREATE TABLE processed_notes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    raw_note_id INTEGER NOT NULL,
    concepts TEXT, -- JSON array of extracted concepts
    concept_confidence TEXT, -- JSON object with confidence scores
    primary_theme TEXT,
    secondary_themes TEXT, -- JSON array of secondary themes
    theme_confidence REAL,
    sentiment_analyzed INTEGER DEFAULT 0,
    sentiment_data TEXT, -- JSON object with sentiment analysis
    overall_sentiment TEXT,
    sentiment_score REAL,
    emotional_tone TEXT,
    energy_level TEXT,
    sentiment_analyzed_at DATETIME,
    processed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (raw_note_id) REFERENCES raw_notes(id)
);
CREATE TABLE sentiment_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    processed_note_id INTEGER NOT NULL,
    raw_note_id INTEGER NOT NULL,
    overall_sentiment TEXT,
    sentiment_score REAL,
    emotional_tone TEXT,
    energy_level TEXT,
    stress_indicators INTEGER DEFAULT 0,
    key_emotions TEXT, -- JSON array
    adhd_markers TEXT, -- JSON object
    analysis_confidence REAL,
    analyzed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (processed_note_id) REFERENCES processed_notes(id),
    FOREIGN KEY (raw_note_id) REFERENCES raw_notes(id)
);
CREATE TABLE detected_patterns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pattern_type TEXT NOT NULL, -- theme_trend, concept_cluster, etc.
    pattern_name TEXT NOT NULL,
    description TEXT,
    confidence REAL,
    data_points INTEGER,
    pattern_data TEXT, -- JSON object with pattern details
    time_range_start DATETIME,
    time_range_end DATETIME,
    insights TEXT,
    discovered_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    is_active INTEGER DEFAULT 1
);
CREATE TABLE pattern_reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    report_id TEXT UNIQUE NOT NULL,
    generated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    time_range_start DATETIME,
    time_range_end DATETIME,
    total_patterns INTEGER,
    high_confidence_count INTEGER,
    medium_confidence_count INTEGER,
    low_confidence_count INTEGER,
    rising_trends_count INTEGER,
    falling_trends_count INTEGER,
    key_insights TEXT, -- JSON array
    recommendations TEXT, -- JSON array
    report_data TEXT -- JSON object with full report
);
CREATE TABLE network_analysis_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    analysis_id TEXT UNIQUE NOT NULL,
    total_notes INTEGER,
    total_connections INTEGER,
    avg_connection_strength REAL,
    concept_based_count INTEGER,
    theme_based_count INTEGER,
    network_stats TEXT, -- JSON object with detailed stats
    analyzed_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_raw_notes_status ON raw_notes(status);
CREATE INDEX idx_raw_notes_content_hash ON raw_notes(content_hash);
CREATE INDEX idx_raw_notes_created_at ON raw_notes(created_at);
CREATE INDEX idx_raw_notes_exported ON raw_notes(exported_to_obsidian);
CREATE INDEX idx_processed_notes_raw_id ON processed_notes(raw_note_id);
CREATE INDEX idx_processed_notes_sentiment ON processed_notes(sentiment_analyzed);
CREATE INDEX idx_sentiment_history_note_ids ON sentiment_history(processed_note_id, raw_note_id);
CREATE INDEX idx_detected_patterns_active ON detected_patterns(is_active);
CREATE INDEX idx_detected_patterns_type ON detected_patterns(pattern_type);
