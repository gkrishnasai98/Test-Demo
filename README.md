# AI Demo App

A standalone playground for AI developer analytics: OpenAI usage, GitHub DevEx metrics, Cursor telemetry, cross-tool identity resolution, and a LangGraph supervisor agent with SQL-generating insights.


## Architecture

- **Backend** (FastAPI + LangGraph): Supervisor agent with insights & monitoring tools
- **Frontend** (React + Vite + Mantine): Dashboard metric cards + AI chat panel
- **DuckDB**: Local analytics store with consumption layer views
- **MongoDB + Redis**: Chat persistence, usage budgets (via Docker)
- **Real data ingestion**: OpenAI Usage API, GitHub API, Cursor local telemetry, Langfuse traces

## Prerequisites

| Service | Purpose |
|---------|---------|
| Docker | MongoDB + Redis |
| Python 3.10+ | Backend |
| Node 18+ | Frontend |
| OpenAI API key | LLM agent + usage data |
| GitHub PAT | Commits, PRs, repos |
| Langfuse (optional) | Prompt monitoring |

## Quick Start

```bash
# 1. Infrastructure
cd ai-demo-app
docker compose up -d

# 2. Configure
cp .env.example .env
# Edit .env with your OPENAI_API_KEY, GITHUB_TOKEN, etc.

# 3. Backend
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python main.py

# 4. Frontend (new terminal)
cd frontend
npm install
npm run dev
```

Open http://localhost:5173

Use the **User / Admin** toggle in the top-right corner of the dashboard to switch roles.

## First-Time Data Load

After configuring credentials in `.env`:

```bash
# Bootstrap GitHub test repo (optional, if you have minimal activity)
curl -X POST http://localhost:8000/api/ingest/github/bootstrap -H "X-API-Key: demo-key-12345"

# Pull all data
curl -X POST http://localhost:8000/api/ingest/all -H "X-API-Key: demo-key-12345"
```

Or use the **Ingest All Data** button in the dashboard UI.

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `POST /api/chat/stream` | SSE chat with supervisor agent |
| `GET /api/metrics/summary` | Dashboard metric cards |
| `GET /api/users/` | Unified identity mappings |
| `POST /api/ingest/all` | Pull data from all sources |
| `GET /api/admin/usage` | Token budget (admin key) |
| `GET /api/admin/prompts` | Prompt audit log (admin key) |

## DuckDB Views (for LLM SQL)

The insights agent uses SKILL markdown files + schema introspection to generate SQL against:

- `v_llm_token_summary` - OpenAI + Cursor token usage
- `v_devex_summary` - GitHub commits & PRs
- `v_cross_tool_metrics` - Unified user 360 view
- `v_tool_adoption` - Tool usage flags
- `v_agent_usage` - Langfuse agent traces

## Example Chat Questions

1. "Show my OpenAI token usage by model for the last month"
2. "What's my most expensive model?"
3. "Show my GitHub commit activity vs Cursor usage"
4. "Give me a 360 view of my developer activity"
5. "What's my remaining token budget?"
6. "Show prompt history for the last 24 hours"

## Switching to Databricks

Set `DATA_ENGINE=databricks` in `.env` and configure Databricks credentials. See `data/databricks/README.md`.

## Project Structure

```
ai-demo-app/
├── backend/          # FastAPI + LangGraph agent
├── frontend/         # React dashboard + chat
├── data/sql/         # DuckDB schema + views
└── docker-compose.yml
```

## Accounts to Set Up

1. **OpenAI API** (~$5 pay-per-use): https://platform.openai.com
2. **GitHub PAT** (free): Settings → Developer settings → Personal access tokens
3. **Langfuse** (free tier): https://cloud.langfuse.com

Copilot Free tier does not expose metrics API; this demo uses OpenAI Usage API for LLM token analytics instead.
