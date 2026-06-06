#!/usr/bin/env python3
"""Deploy schema, views, and optional seed data to Databricks.

Usage:
    python scripts/deploy_databricks.py                 # Deploy schema + views
    python scripts/deploy_databricks.py --seed          # Deploy schema + views + seed data
    python scripts/deploy_databricks.py --seed-only     # Only seed data (schema must exist)
    python scripts/deploy_databricks.py --check         # Test connection only

Requires env vars: DATABRICKS_HOST, DATABRICKS_TOKEN, DATABRICKS_WAREHOUSE_ID
Optional: DATABRICKS_CATALOG (default: playground), DATABRICKS_SCHEMA (default: ai_demo)
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT_DIR / "backend"))

from dotenv import load_dotenv

load_dotenv(ROOT_DIR / ".env")


def get_connection():
    from databricks import sql as dbsql

    host = os.environ.get("DATABRICKS_HOST", "").replace("https://", "").replace("http://", "")
    token = os.environ.get("DATABRICKS_TOKEN", "")
    warehouse_id = os.environ.get("DATABRICKS_WAREHOUSE_ID", "")

    if not all([host, token, warehouse_id]):
        print("ERROR: DATABRICKS_HOST, DATABRICKS_TOKEN, and DATABRICKS_WAREHOUSE_ID must be set")
        sys.exit(1)

    return dbsql.connect(
        server_hostname=host,
        http_path=f"/sql/1.0/warehouses/{warehouse_id}",
        access_token=token,
    )


def get_catalog_schema():
    catalog = os.environ.get("DATABRICKS_CATALOG", "playground")
    schema = os.environ.get("DATABRICKS_SCHEMA", "ai_demo")
    return catalog, schema


def substitute_placeholders(sql: str, catalog: str, schema: str) -> str:
    return sql.replace("{{catalog}}", catalog).replace("{{schema}}", schema)


def check_connection():
    print("Testing Databricks connection...")
    try:
        with get_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("SELECT 1 AS check_val")
                result = cursor.fetchone()
                print(f"  Connection OK (result: {result[0]})")

        catalog, schema = get_catalog_schema()
        print(f"  Target: {catalog}.{schema}")
        return True
    except Exception as exc:
        print(f"  Connection FAILED: {exc}")
        return False


def deploy_schema():
    catalog, schema = get_catalog_schema()
    sql_path = ROOT_DIR / "data" / "databricks" / "deploy_schema.sql"

    if not sql_path.exists():
        print(f"ERROR: Schema file not found: {sql_path}")
        sys.exit(1)

    raw_sql = sql_path.read_text()
    sql = substitute_placeholders(raw_sql, catalog, schema)

    print(f"Deploying schema to {catalog}.{schema}...")

    statements = [s.strip() for s in sql.split(";") if s.strip() and not s.strip().startswith("--")]

    with get_connection() as conn:
        with conn.cursor() as cursor:
            for i, stmt in enumerate(statements, 1):
                try:
                    cursor.execute(stmt)
                    print(f"  [{i}/{len(statements)}] OK")
                except Exception as exc:
                    print(f"  [{i}/{len(statements)}] WARN: {exc}")

    print(f"Schema deployment complete ({len(statements)} statements)")


def deploy_views():
    catalog, schema = get_catalog_schema()
    sql_path = ROOT_DIR / "data" / "databricks" / "deploy_views.sql"

    if not sql_path.exists():
        print(f"ERROR: Views file not found: {sql_path}")
        sys.exit(1)

    raw_sql = sql_path.read_text()
    sql = substitute_placeholders(raw_sql, catalog, schema)

    print(f"Deploying views to {catalog}.{schema}...")

    statements = [s.strip() for s in sql.split(";") if s.strip() and not s.strip().startswith("--")]

    with get_connection() as conn:
        with conn.cursor() as cursor:
            for i, stmt in enumerate(statements, 1):
                try:
                    cursor.execute(stmt)
                    print(f"  [{i}/{len(statements)}] OK")
                except Exception as exc:
                    print(f"  [{i}/{len(statements)}] WARN: {exc}")

    print(f"Views deployment complete ({len(statements)} statements)")


def seed_data():
    """Generate synthetic data and write to Databricks."""
    catalog, schema = get_catalog_schema()
    print(f"Seeding data into {catalog}.{schema}...")

    from ingestion.seed_data import (
        _generate_copilot_seats,
        _generate_cursor_sessions,
        _generate_github_commits,
        _generate_github_prs,
        _generate_github_repos,
        _generate_langfuse_traces,
        _generate_openai_usage,
        _generate_unified_users,
    )

    table_data = [
        ("openai_usage",
         ["usage_date", "model", "requests", "prompt_tokens", "completion_tokens", "total_tokens", "cost_usd", "openai_user"],
         _generate_openai_usage()),
        ("github_repos",
         ["repo_name", "owner", "language", "stars", "forks", "created_at", "pushed_at"],
         _generate_github_repos()),
        ("github_commits",
         ["commit_sha", "repo", "author_login", "author_email", "commit_date", "lines_added", "lines_deleted", "message"],
         _generate_github_commits()),
        ("github_pull_requests",
         ["pr_id", "repo", "pr_number", "author_login", "created_at", "merged_at", "state", "additions", "deletions", "review_count", "comments"],
         _generate_github_prs()),
        ("github_copilot_seats",
         ["login", "org_name", "last_activity_at", "plan_type", "editor", "last_editor_used", "is_active"],
         _generate_copilot_seats()),
        ("cursor_sessions",
         ["session_id", "session_date", "model_used", "tokens_estimated", "duration_mins", "session_type", "cursor_user"],
         _generate_cursor_sessions()),
        ("langfuse_traces",
         ["trace_id", "timestamp", "user_id", "model", "prompt_tokens", "completion_tokens", "total_tokens", "latency_ms", "cost_usd", "tool_calls", "prompt_text"],
         _generate_langfuse_traces()),
        ("unified_users",
         ["canonical_id", "github_login", "github_email", "openai_user", "cursor_user", "full_name"],
         _generate_unified_users()),
    ]

    fqn_prefix = f"{catalog}.{schema}"
    placeholders_cache: dict[int, str] = {}

    with get_connection() as conn:
        with conn.cursor() as cursor:
            for table_name, columns, rows in table_data:
                fqn = f"{fqn_prefix}.{table_name}"
                # Truncate first
                try:
                    cursor.execute(f"TRUNCATE TABLE {fqn}")
                except Exception:
                    pass

                if not rows:
                    print(f"  {table_name}: 0 rows (skipped)")
                    continue

                col_count = len(columns)
                if col_count not in placeholders_cache:
                    placeholders_cache[col_count] = ", ".join(["%s"] * col_count)
                ph = placeholders_cache[col_count]
                col_list = ", ".join(columns)

                batch_size = 200
                total_inserted = 0
                for i in range(0, len(rows), batch_size):
                    batch = rows[i : i + batch_size]
                    values_parts = []
                    params: list = []
                    for row in batch:
                        values_parts.append(f"({ph})")
                        params.extend(row)
                    sql = f"INSERT INTO {fqn} ({col_list}) VALUES {', '.join(values_parts)}"
                    cursor.execute(sql, params)
                    total_inserted += len(batch)

                print(f"  {table_name}: {total_inserted} rows")

    print("Seed complete!")


def main():
    parser = argparse.ArgumentParser(description="Deploy AI Demo App to Databricks")
    parser.add_argument("--check", action="store_true", help="Test connection only")
    parser.add_argument("--seed", action="store_true", help="Deploy schema + views + seed data")
    parser.add_argument("--seed-only", action="store_true", help="Only seed data (schema must exist)")
    args = parser.parse_args()

    if args.check:
        success = check_connection()
        sys.exit(0 if success else 1)

    if args.seed_only:
        if not check_connection():
            sys.exit(1)
        seed_data()
        return

    if not check_connection():
        sys.exit(1)

    deploy_schema()
    deploy_views()

    if args.seed:
        seed_data()

    print("\nDone! Set DATA_ENGINE=databricks in .env to query from Databricks.")


if __name__ == "__main__":
    main()
