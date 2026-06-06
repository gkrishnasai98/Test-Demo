-- DuckDB schema for AI Demo App (real API ingestion)

CREATE TABLE IF NOT EXISTS openai_usage (
    usage_date DATE NOT NULL,
    model VARCHAR NOT NULL,
    requests INTEGER DEFAULT 0,
    prompt_tokens BIGINT DEFAULT 0,
    completion_tokens BIGINT DEFAULT 0,
    total_tokens BIGINT DEFAULT 0,
    cost_usd DECIMAL(12, 6) DEFAULT 0,
    openai_user VARCHAR,
    ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS github_commits (
    commit_sha VARCHAR PRIMARY KEY,
    repo VARCHAR NOT NULL,
    author_login VARCHAR,
    author_email VARCHAR,
    commit_date TIMESTAMP,
    lines_added INTEGER DEFAULT 0,
    lines_deleted INTEGER DEFAULT 0,
    message VARCHAR,
    ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS github_pull_requests (
    pr_id VARCHAR PRIMARY KEY,
    repo VARCHAR NOT NULL,
    pr_number INTEGER,
    author_login VARCHAR,
    created_at TIMESTAMP,
    merged_at TIMESTAMP,
    state VARCHAR,
    additions INTEGER DEFAULT 0,
    deletions INTEGER DEFAULT 0,
    review_count INTEGER DEFAULT 0,
    comments INTEGER DEFAULT 0,
    ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS github_repos (
    repo_name VARCHAR PRIMARY KEY,
    owner VARCHAR,
    language VARCHAR,
    stars INTEGER DEFAULT 0,
    forks INTEGER DEFAULT 0,
    created_at TIMESTAMP,
    pushed_at TIMESTAMP,
    ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS github_copilot_seats (
    login VARCHAR,
    org_name VARCHAR,
    last_activity_at TIMESTAMP,
    plan_type VARCHAR,
    editor VARCHAR,
    last_editor_used VARCHAR,
    is_active BOOLEAN DEFAULT TRUE,
    ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS cursor_sessions (
    session_id VARCHAR PRIMARY KEY,
    session_date DATE NOT NULL,
    model_used VARCHAR,
    tokens_estimated BIGINT DEFAULT 0,
    duration_mins INTEGER DEFAULT 0,
    session_type VARCHAR,
    cursor_user VARCHAR,
    ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS langfuse_traces (
    trace_id VARCHAR PRIMARY KEY,
    timestamp TIMESTAMP NOT NULL,
    user_id VARCHAR,
    model VARCHAR,
    prompt_tokens BIGINT DEFAULT 0,
    completion_tokens BIGINT DEFAULT 0,
    total_tokens BIGINT DEFAULT 0,
    latency_ms INTEGER DEFAULT 0,
    cost_usd DECIMAL(12, 6) DEFAULT 0,
    tool_calls INTEGER DEFAULT 0,
    prompt_text VARCHAR,
    ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS unified_users (
    canonical_id VARCHAR PRIMARY KEY,
    github_login VARCHAR,
    github_email VARCHAR,
    openai_user VARCHAR,
    cursor_user VARCHAR,
    full_name VARCHAR,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
