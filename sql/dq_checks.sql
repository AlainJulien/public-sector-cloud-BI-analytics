-- =============================================================================
-- dq_checks.sql
-- Layer:   Quality Assurance
-- Purpose: Validates data integrity between raw and curated layers.
--          Run after each curated table creation to confirm row counts,
--          null foreign keys, and bounds compliance before dashboards
--          consume the data.
-- Engine:  Amazon Athena (Presto SQL)
-- Depends: ps_cloud_raw.*, ps_cloud_curated.*
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. ROW COUNT RECONCILIATION
--    Confirms curated fact tables account for all raw source rows.
--    Variance > 0 indicates rows were rejected during transformation
--    (e.g. null agency_id, unparseable dates) and should be investigated.
-- -----------------------------------------------------------------------------

SELECT
    'fact_usage_monthly'            AS table_name,
    'Row count reconciliation'      AS check_type,
    (SELECT COUNT(*) FROM ps_cloud_curated.fact_usage_monthly)
                                    AS curated_rows,
    (SELECT COUNT(*) FROM ps_cloud_raw.ps_cloud_raw_usage_monthly)
                                    AS raw_rows,
    (SELECT COUNT(*) FROM ps_cloud_curated.fact_usage_monthly)
    - (SELECT COUNT(*) FROM ps_cloud_raw.ps_cloud_raw_usage_monthly)
                                    AS variance

UNION ALL

SELECT
    'fact_migration_summary',
    'Row count reconciliation',
    (SELECT COUNT(*) FROM ps_cloud_curated.fact_migration_summary),
    (SELECT COUNT(*) FROM ps_cloud_raw.ps_cloud_raw_migration_summary),
    (SELECT COUNT(*) FROM ps_cloud_curated.fact_migration_summary)
    - (SELECT COUNT(*) FROM ps_cloud_raw.ps_cloud_raw_migration_summary)

UNION ALL

SELECT
    'fact_tagging_compliance',
    'Row count reconciliation',
    (SELECT COUNT(*) FROM ps_cloud_curated.fact_tagging_compliance),
    (SELECT COUNT(*) FROM ps_cloud_raw.ps_cloud_raw_tagging_compliance),
    (SELECT COUNT(*) FROM ps_cloud_curated.fact_tagging_compliance)
    - (SELECT COUNT(*) FROM ps_cloud_raw.ps_cloud_raw_tagging_compliance)

UNION ALL

SELECT
    'fact_provider_spend',
    'Row count reconciliation',
    (SELECT COUNT(*) FROM ps_cloud_curated.fact_provider_spend),
    (SELECT COUNT(*) FROM ps_cloud_raw.ps_cloud_raw_provider_spend),
    (SELECT COUNT(*) FROM ps_cloud_curated.fact_provider_spend)
    - (SELECT COUNT(*) FROM ps_cloud_raw.ps_cloud_raw_provider_spend)

UNION ALL

SELECT
    'fact_cost_monthly',
    'Row count reconciliation',
    (SELECT COUNT(*) FROM ps_cloud_curated.fact_cost_monthly),
    (SELECT COUNT(*) FROM ps_cloud_raw.ps_cloud_raw_usage_monthly),
    (SELECT COUNT(*) FROM ps_cloud_curated.fact_cost_monthly)
    - (SELECT COUNT(*) FROM ps_cloud_raw.ps_cloud_raw_usage_monthly);


-- -----------------------------------------------------------------------------
-- 2. NULL FOREIGN KEY CHECKS
--    Any null on a dimension key means a fact row cannot be filtered or
--    grouped correctly in the dashboard. These should return 0 rows.
-- -----------------------------------------------------------------------------

-- Null agency_id in fact_usage_monthly
SELECT
    'fact_usage_monthly'        AS table_name,
    'Null agency_id'            AS check_type,
    COUNT(*)                    AS failing_rows
FROM ps_cloud_curated.fact_usage_monthly
WHERE agency_id IS NULL

UNION ALL

-- Null date_key in fact_usage_monthly (indicates unparseable month value)
SELECT
    'fact_usage_monthly',
    'Null date_key',
    COUNT(*)
FROM ps_cloud_curated.fact_usage_monthly
WHERE date_key IS NULL

UNION ALL

-- Null service_id (unmatched service_type in dim_service)
SELECT
    'fact_usage_monthly',
    'Null service_id',
    COUNT(*)
FROM ps_cloud_curated.fact_usage_monthly
WHERE service_id IS NULL

UNION ALL

-- Null region_id (unmatched aws_region in dim_region)
SELECT
    'fact_usage_monthly',
    'Null region_id',
    COUNT(*)
FROM ps_cloud_curated.fact_usage_monthly
WHERE region_id IS NULL

UNION ALL

-- Null date_key in fact_tagging_compliance
-- NOTE: If this returns > 0, check date format in facts.sql
-- The join uses '%Y-%m-%d' -- confirm source month format matches
SELECT
    'fact_tagging_compliance',
    'Null date_key',
    COUNT(*)
FROM ps_cloud_curated.fact_tagging_compliance
WHERE date_key IS NULL

UNION ALL

-- Null date_key in fact_cost_monthly
SELECT
    'fact_cost_monthly',
    'Null date_key',
    COUNT(*)
FROM ps_cloud_curated.fact_cost_monthly
WHERE date_key IS NULL;


-- -----------------------------------------------------------------------------
-- 3. BOUNDS CHECKS
--    Validates that numeric fields fall within expected operational ranges.
--    Out-of-bounds values indicate data generation errors or ingestion issues.
-- -----------------------------------------------------------------------------

-- Utilisation must be between 0 and 100
SELECT
    'fact_usage_monthly'            AS table_name,
    'Utilisation out of bounds'     AS check_type,
    COUNT(*)                        AS failing_rows
FROM ps_cloud_curated.fact_usage_monthly
WHERE utilisation_pct < 0 OR utilisation_pct > 100

UNION ALL

-- Cost must not be negative
SELECT
    'fact_usage_monthly',
    'Negative cost_usd',
    COUNT(*)
FROM ps_cloud_curated.fact_usage_monthly
WHERE cost_usd < 0

UNION ALL

-- Compute hours must not be negative
SELECT
    'fact_usage_monthly',
    'Negative compute_hours',
    COUNT(*)
FROM ps_cloud_curated.fact_usage_monthly
WHERE compute_hours < 0

UNION ALL

-- Tagged percentage must be between 0 and 100
SELECT
    'fact_tagging_compliance',
    'tagged_pct out of bounds',
    COUNT(*)
FROM ps_cloud_curated.fact_tagging_compliance
WHERE tagged_pct < 0 OR tagged_pct > 100

UNION ALL

-- Untagged cost must not be negative
SELECT
    'fact_tagging_compliance',
    'Negative untagged_cost_usd',
    COUNT(*)
FROM ps_cloud_curated.fact_tagging_compliance
WHERE untagged_cost_usd < 0

UNION ALL

-- Provider share must be between 0 and 1
SELECT
    'fact_provider_spend',
    'provider_share_pct out of bounds',
    COUNT(*)
FROM ps_cloud_curated.fact_provider_spend
WHERE provider_share_pct < 0 OR provider_share_pct > 1;


-- -----------------------------------------------------------------------------
-- 4. DIMENSION REFERENTIAL INTEGRITY
--    Confirms all agency IDs in fact tables exist in dim_agency_clean.
--    Orphaned IDs indicate a lookup gap and will cause blank labels in
--    dashboard filters.
-- -----------------------------------------------------------------------------

-- Orphaned agency_id in fact_usage_monthly
SELECT
    'fact_usage_monthly'            AS table_name,
    'Orphaned agency_id'            AS check_type,
    COUNT(*)                        AS failing_rows
FROM ps_cloud_curated.fact_usage_monthly f
LEFT JOIN ps_cloud_curated.dim_agency_clean a
    ON f.agency_id = a.agency_id
WHERE a.agency_id IS NULL

UNION ALL

-- Orphaned agency_id in fact_tagging_compliance
SELECT
    'fact_tagging_compliance',
    'Orphaned agency_id',
    COUNT(*)
FROM ps_cloud_curated.fact_tagging_compliance f
LEFT JOIN ps_cloud_curated.dim_agency_clean a
    ON f.agency_id = a.agency_id
WHERE a.agency_id IS NULL

UNION ALL

-- Orphaned agency_id in fact_migration_summary
SELECT
    'fact_migration_summary',
    'Orphaned agency_id',
    COUNT(*)
FROM ps_cloud_curated.fact_migration_summary f
LEFT JOIN ps_cloud_curated.dim_agency_clean a
    ON f.agency_id = a.agency_id
WHERE a.agency_id IS NULL;


-- -----------------------------------------------------------------------------
-- 5. TAGGING DATE FORMAT VALIDATION
--    Specifically targets the known date format risk in fact_tagging_compliance.
--    Checks raw source to confirm month values are in 'YYYY-MM' format
--    before the join to dim_date is attempted.
-- -----------------------------------------------------------------------------

SELECT
    'ps_cloud_raw_tagging_compliance'   AS table_name,
    'Invalid month format'              AS check_type,
    COUNT(*)                            AS failing_rows
FROM ps_cloud_raw.ps_cloud_raw_tagging_compliance
WHERE NOT regexp_like(month, '^\d{4}-\d{2}$');


-- =============================================================================
-- EXPECTED RESULTS SUMMARY
-- All checks above should return 0 in the failing_rows column.
-- Any non-zero result requires investigation before dashboard publication.
-- =============================================================================
