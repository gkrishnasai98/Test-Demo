-- Databricks Unity Catalog consumption views
-- Placeholders: {{catalog}} and {{schema}} are replaced at deploy time
-- These mirror data/sql/views.sql with Databricks SQL syntax

USE CATALOG {{catalog}};
USE SCHEMA {{schema}};

-- LLM token usage across OpenAI and Cursor sources
CREATE OR REPLACE VIEW {{catalog}}.{{schema}}.v_llm_token_summary AS
SELECT
    'openai' AS source,
    usage_date,
    model,
    SUM(requests) AS total_requests,
    SUM(prompt_tokens) AS prompt_tokens,
    SUM(completion_tokens) AS completion_tokens,
    SUM(total_tokens) AS total_tokens,
    SUM(cost_usd) AS cost_usd,
    openai_user AS user_identifier
FROM {{catalog}}.{{schema}}.openai_usage
GROUP BY usage_date, model, openai_user
UNION ALL
SELECT
    'cursor' AS source,
    session_date AS usage_date,
    model_used AS model,
    COUNT(*) AS total_requests,
    SUM(tokens_estimated) AS prompt_tokens,
    CAST(0 AS BIGINT) AS completion_tokens,
    SUM(tokens_estimated) AS total_tokens,
    CAST(0.0 AS DECIMAL(12,6)) AS cost_usd,
    cursor_user AS user_identifier
FROM {{catalog}}.{{schema}}.cursor_sessions
GROUP BY session_date, model_used, cursor_user;

-- Developer experience summary from GitHub activity
CREATE OR REPLACE VIEW {{catalog}}.{{schema}}.v_devex_summary AS
SELECT
    COALESCE(c.author_login, p.author_login) AS author_login,
    COUNT(DISTINCT c.commit_sha) AS total_commits,
    COALESCE(SUM(c.lines_added), 0) AS total_lines_added,
    COALESCE(SUM(c.lines_deleted), 0) AS total_lines_deleted,
    COUNT(DISTINCT p.pr_id) AS total_prs,
    SUM(CASE WHEN p.merged_at IS NOT NULL THEN 1 ELSE 0 END) AS merged_prs,
    AVG(CASE
        WHEN p.merged_at IS NOT NULL AND p.created_at IS NOT NULL
        THEN UNIX_TIMESTAMP(p.merged_at) - UNIX_TIMESTAMP(p.created_at)
    END) / 3600.0 AS avg_pr_merge_hours
FROM {{catalog}}.{{schema}}.github_commits c
FULL OUTER JOIN {{catalog}}.{{schema}}.github_pull_requests p
    ON c.author_login = p.author_login
GROUP BY COALESCE(c.author_login, p.author_login);

-- 360-degree cross-tool metrics per user
CREATE OR REPLACE VIEW {{catalog}}.{{schema}}.v_cross_tool_metrics AS
SELECT
    u.canonical_id,
    u.full_name,
    u.github_login,
    u.openai_user,
    u.cursor_user,
    COALESCE(o.total_openai_tokens, 0) AS openai_tokens,
    COALESCE(o.openai_cost, 0) AS openai_cost,
    COALESCE(cur.cursor_tokens, 0) AS cursor_tokens,
    COALESCE(d.total_commits, 0) AS github_commits,
    COALESCE(d.total_prs, 0) AS github_prs,
    COALESCE(lf.agent_tokens, 0) AS agent_tokens_used
FROM {{catalog}}.{{schema}}.unified_users u
LEFT JOIN (
    SELECT openai_user, SUM(total_tokens) AS total_openai_tokens, SUM(cost_usd) AS openai_cost
    FROM {{catalog}}.{{schema}}.openai_usage GROUP BY openai_user
) o ON u.openai_user = o.openai_user OR u.github_login = o.openai_user
LEFT JOIN (
    SELECT cursor_user, SUM(tokens_estimated) AS cursor_tokens
    FROM {{catalog}}.{{schema}}.cursor_sessions GROUP BY cursor_user
) cur ON u.cursor_user = cur.cursor_user OR u.github_login = cur.cursor_user
LEFT JOIN {{catalog}}.{{schema}}.v_devex_summary d ON u.github_login = d.author_login
LEFT JOIN (
    SELECT user_id, SUM(total_tokens) AS agent_tokens
    FROM {{catalog}}.{{schema}}.langfuse_traces GROUP BY user_id
) lf ON u.canonical_id = lf.user_id OR u.github_login = lf.user_id;

-- Tool adoption flags per user
CREATE OR REPLACE VIEW {{catalog}}.{{schema}}.v_tool_adoption AS
SELECT
    u.canonical_id,
    u.full_name,
    CASE WHEN o.cnt > 0 THEN TRUE ELSE FALSE END AS uses_openai,
    CASE WHEN cur.cnt > 0 THEN TRUE ELSE FALSE END AS uses_cursor,
    CASE WHEN gh.cnt > 0 THEN TRUE ELSE FALSE END AS uses_github,
    CASE WHEN lf.cnt > 0 THEN TRUE ELSE FALSE END AS uses_agent,
    COALESCE(o.cnt, 0) AS openai_days_active,
    COALESCE(cur.cnt, 0) AS cursor_sessions_count,
    COALESCE(gh.cnt, 0) AS github_commits_count
FROM {{catalog}}.{{schema}}.unified_users u
LEFT JOIN (SELECT openai_user, COUNT(DISTINCT usage_date) AS cnt FROM {{catalog}}.{{schema}}.openai_usage GROUP BY openai_user) o
    ON u.openai_user = o.openai_user
LEFT JOIN (SELECT cursor_user, COUNT(*) AS cnt FROM {{catalog}}.{{schema}}.cursor_sessions GROUP BY cursor_user) cur
    ON u.cursor_user = cur.cursor_user
LEFT JOIN (SELECT author_login, COUNT(*) AS cnt FROM {{catalog}}.{{schema}}.github_commits GROUP BY author_login) gh
    ON u.github_login = gh.author_login
LEFT JOIN (SELECT user_id, COUNT(*) AS cnt FROM {{catalog}}.{{schema}}.langfuse_traces GROUP BY user_id) lf
    ON u.canonical_id = lf.user_id;

-- Daily agent usage rollup from Langfuse traces
CREATE OR REPLACE VIEW {{catalog}}.{{schema}}.v_agent_usage AS
SELECT
    DATE_TRUNC('DAY', timestamp) AS usage_date,
    user_id,
    model,
    COUNT(*) AS trace_count,
    SUM(prompt_tokens) AS prompt_tokens,
    SUM(completion_tokens) AS completion_tokens,
    SUM(total_tokens) AS total_tokens,
    SUM(cost_usd) AS cost_usd,
    AVG(latency_ms) AS avg_latency_ms,
    SUM(tool_calls) AS tool_calls
FROM {{catalog}}.{{schema}}.langfuse_traces
GROUP BY DATE_TRUNC('DAY', timestamp), user_id, model;
