# SQL Layer — Execution Order & Script Guide

This folder contains all SQL transformation scripts for the  
**Cloud Migration Analytics – Cost & Reliability (Public Sector)** portfolio project.

Scripts are written for **Amazon Athena (Presto SQL)** against an AWS Glue  
Data Catalog. Raw data is stored in Amazon S3 and accessed via external tables.

---

## Architecture

```
S3 (Raw CSVs)
     │
     ▼
AWS Glue Data Catalog  ──  Schema management & table registration
     │
     ▼
Amazon Athena  ──  SQL transformations (CTAS → Parquet in S3)
     │
     ├── Raw Layer          (ps_cloud_raw database)
     └── Curated Layer      (ps_cloud_curated database)
          │
          ├── Dimensions:   dim_agency_clean, dim_service,
          │                 dim_region, dim_date
          │
          ├── Facts:        fact_usage_monthly, fact_cost_monthly,
          │                 fact_performance, fact_migration_summary,
          │                 fact_tagging_compliance, fact_provider_spend,
          │                 fact_provider_finance, fact_finance_governance,
          │                 fact_forecast_input
          │
          └── Views:        v_cost_spikes, v_cloud_waste,
                            v_cost_trends, v_budget_runrate,
                            v_seasonality_index, v_sla_bands
```

---

## Execution Order

Run scripts in the following order. Each script depends on the layer above it.

| Step | Script | Layer | Purpose |
|------|--------|-------|---------|
| 1 | `raw.sql` | Raw | Creates `ps_cloud_raw` and `ps_cloud_curated` databases. Defines external tables pointing to S3 CSV sources. |
| 2 | `curated.sql` | Curated | Creates conformed dimensions (`dim_agency_clean`, `dim_service`, `dim_region`, `dim_date`) as Parquet CTAS tables. |
| 3 | `facts.sql` | Curated | Creates all fact tables and financial/governance views. Includes synthetic derived metrics (latency model, SLA breach flags, cost efficiency ratios, provider share). |
| 4 | `derived_metrics.sql` | Curated | Creates analytical views for cost trends, run-rate projections, seasonality indexing, and SLA banding. These are the primary inputs for dashboard KPIs. |
| 5 | `dq_checks.sql` | QA | Validates data integrity across raw and curated layers. Should return 0 failing rows on all checks before the Power BI dashboard is refreshed. |

---

## Key Design Decisions

**Why star schema?**  
Conformed dimensions (`dim_agency_clean`, `dim_service`, `dim_date`, `dim_region`) are shared across both case studies — Reliability and Budget Governance. This allows cost, performance, and governance metrics to be analysed consistently without duplicating organisational or temporal context.

**Why Athena/Glue over a traditional data warehouse?**  
The serverless architecture reflects realistic AWS-native patterns for Caribbean public sector organisations with limited dedicated cloud engineering capacity. Costs scale with query volume rather than requiring always-on infrastructure, which aligns with FinOps principles.

**Why analytically derived SLA proxies?**  
Portfolio-level BI analysis focuses on trend-based decision support rather than real-time operational alerting. Derived proxies (latency model, error rate simulation, SLA breach flags) allow consistent cross-ministry comparison without requiring integration with individual agency monitoring tools — appropriate for a centralised BI governance layer.

**Why CTAS to Parquet?**  
Parquet columnar storage significantly reduces Athena query costs and improves scan performance on large datasets. In a production environment this also enables partition pruning by month or agency for further efficiency.

**Why `dim_agency_clean` instead of `dim_agency`?**  
`dim_agency_clean` deduplicates on `agency_id` using aggregation, ensuring exactly one row per agency in the dimension. This prevents fan-out on joins in fact tables where an agency might appear multiple times in the raw source.

---

## Data Quality

All transformations include sanity checks (`SELECT ... LIMIT 5`) for interactive  
validation during development.

Run `dq_checks.sql` after any data refresh to confirm:
- Row counts reconcile between raw and curated layers
- No null foreign keys on dimension joins
- All numeric fields within expected operational bounds
- All agency IDs resolvable in `dim_agency_clean`

Any non-zero result in `dq_checks.sql` should be investigated before  
dashboard publication.

---

## Notes on Synthetic Data

All datasets are synthetic and generated for demonstration purposes.  
They do not represent real government cloud spending, compliance records,  
or operational data.

Data quality checks are included despite the synthetic source because  
AI-generated data can still contain structural errors (null values,  
format inconsistencies, out-of-bounds numerics) that would silently  
corrupt dashboard outputs.
