# Deploying to Databricks

1. Create catalog and schemas: `playground`, or map to your catalog.
2. Run `data/sql/schema.sql` to create base tables (after loading data via your pipeline).
3. Adapt `data/sql/views.sql` for Databricks SQL syntax if needed.
4. Set in `.env`:

```env
DATA_ENGINE=databricks
DATABRICKS_HOST=https://your-workspace.cloud.databricks.com
DATABRICKS_TOKEN=dapi...
DATABRICKS_WAREHOUSE_ID=your-warehouse-id
DATABRICKS_CATALOG=playground
```

5. Restart the backend. The query engine will route reads to Databricks instead of DuckDB.

Ingestion still writes to DuckDB by default. For Databricks-only deployments, extend ingestion to write via SQL INSERT or use Delta Live Tables.
