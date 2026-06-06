-- Databricks Unity Catalog schema deployment
-- Run with: scripts/deploy_databricks.py or manually in Databricks SQL Editor
-- Placeholders: {{catalog}} and {{schema}} are replaced at deploy time

-- Create schema if not exists
CREATE SCHEMA IF NOT EXISTS {{catalog}}.{{schema}};

USE CATALOG {{catalog}};
USE SCHEMA {{schema}};

-- OpenAI API usage data
CREATE TABLE IF NOT EXISTS {{catalog}}.{{schema}}.openai_usage (
    usage_date DATE NOT NULL,
    model STRING NOT NULL,
    requests INT DEFAULT 0,
    prompt_tokens BIGINT DEFAULT 0,
    completion_tokens BIGINT DEFAULT 0,
    total_tokens BIGINT DEFAULT 0,
    cost_usd DECIMAL(12, 6) DEFAULT 0,
    openai_user STRING,
    ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
USING DELTA
COMMENT 'OpenAI organization usage data aggregated daily by model';

-- GitHub commits
CREATE TABLE IF NOT EXISTS {{catalog}}.{{schema}}.github_commits (
    commit_sha STRING NOT NULL,
    repo STRING NOT NULL,
    author_login STRING,
    author_email STRING,
    commit_date TIMESTAMP,
    lines_added INT DEFAULT 0,
    lines_deleted INT DEFAULT 0,
    message STRING,
    ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_commits PRIMARY KEY (commit_sha)
)
USING DELTA
COMMENT 'GitHub commit history across monitored repositories';

-- GitHub pull requests
CREATE TABLE IF NOT EXISTS {{catalog}}.{{schema}}.github_pull_requests (
    pr_id STRING NOT NULL,
    repo STRING NOT NULL,
    pr_number INT,
    author_login STRING,
    created_at TIMESTAMP,
    merged_at TIMESTAMP,
    state STRING,
    additions INT DEFAULT 0,
    deletions INT DEFAULT 0,
    review_count INT DEFAULT 0,
    comments INT DEFAULT 0,
    ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_prs PRIMARY KEY (pr_id)
)
USING DELTA
COMMENT 'GitHub pull request metadata and merge metrics';

-- GitHub repositories
CREATE TABLE IF NOT EXISTS {{catalog}}.{{schema}}.github_repos (
    repo_name STRING NOT NULL,
    owner STRING,
    language STRING,
    stars INT DEFAULT 0,
    forks INT DEFAULT 0,
    created_at TIMESTAMP,
    pushed_at TIMESTAMP,
    ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_repos PRIMARY KEY (repo_name)
)
USING DELTA
COMMENT 'GitHub repository metadata';

-- GitHub Copilot seat assignments
CREATE TABLE IF NOT EXISTS {{catalog}}.{{schema}}.github_copilot_seats (
    login STRING,
    org_name STRING,
    last_activity_at TIMESTAMP,
    plan_type STRING,
    editor STRING,
    last_editor_used STRING,
    is_active BOOLEAN DEFAULT TRUE,
    ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
USING DELTA
COMMENT 'GitHub Copilot seat utilization data';

-- Cursor IDE sessions
CREATE TABLE IF NOT EXISTS {{catalog}}.{{schema}}.cursor_sessions (
    session_id STRING NOT NULL,
    session_date DATE NOT NULL,
    model_used STRING,
    tokens_estimated BIGINT DEFAULT 0,
    duration_mins INT DEFAULT 0,
    session_type STRING,
    cursor_user STRING,
    ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_cursor PRIMARY KEY (session_id)
)
USING DELTA
COMMENT 'Cursor IDE session telemetry with token estimates';

-- Langfuse agent traces
CREATE TABLE IF NOT EXISTS {{catalog}}.{{schema}}.langfuse_traces (
    trace_id STRING NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    user_id STRING,
    model STRING,
    prompt_tokens BIGINT DEFAULT 0,
    completion_tokens BIGINT DEFAULT 0,
    total_tokens BIGINT DEFAULT 0,
    latency_ms INT DEFAULT 0,
    cost_usd DECIMAL(12, 6) DEFAULT 0,
    tool_calls INT DEFAULT 0,
    prompt_text STRING,
    ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_traces PRIMARY KEY (trace_id)
)
USING DELTA
COMMENT 'Agent trace telemetry from Langfuse for monitoring and audit';

-- Cross-tool unified user identities
CREATE TABLE IF NOT EXISTS {{catalog}}.{{schema}}.unified_users (
    canonical_id STRING NOT NULL,
    github_login STRING,
    github_email STRING,
    openai_user STRING,
    cursor_user STRING,
    full_name STRING,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_users PRIMARY KEY (canonical_id)
)
USING DELTA
COMMENT 'Cross-tool identity mapping for developer analytics';
