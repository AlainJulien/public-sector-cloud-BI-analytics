-- =============================================================================
-- derived_metrics.sql
-- Layer:   Curated (Analytics)
-- Purpose: Adds trend, forecasting, and budget governance derived metrics
--          on top of the core fact tables. These translate raw cloud cost and
--          usage data into decision-ready financial and operational signals.
-- Engine:  Amazon Athena (Presto SQL)
-- Depends: fact_cost_monthly, fact_performance, dim_date
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. COST TREND VIEW
--    Rolling 3-month average spend and month-over-month growth rate per agency.
--    Supports the "Cost Trends & Forecasting" dashboard page and answers:
--    "Is spend accelerating faster than expected?"
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW ps_cloud_curated.v_cost_trends AS
SELECT
    agency_id,
    date_key,
    service_type,
    cost_usd,

    -- 3-month rolling average (smooths seasonal noise)
    AVG(cost_usd) OVER (
        PARTITION BY agency_id, service_type
        ORDER BY date_key
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS rolling_3m_avg_cost,

    -- Month-over-month spend growth rate
    ROUND(
        (
            cost_usd
            - LAG(cost_usd) OVER (
                PARTITION BY agency_id, service_type
                ORDER BY date_key
              )
        )
        / NULLIF(
            LAG(cost_usd) OVER (
                PARTITION BY agency_id, service_type
                ORDER BY date_key
              ),
          0) * 100,
    2) AS mom_growth_pct,

    -- Spend acceleration flag: MoM growth > 15% triggers early warning
    CASE
        WHEN (
            (
                cost_usd
                - LAG(cost_usd) OVER (
                    PARTITION BY agency_id, service_type
                    ORDER BY date_key
                  )
            )
            / NULLIF(
                LAG(cost_usd) OVER (
                    PARTITION BY agency_id, service_type
                    ORDER BY date_key
                  ),
              0) * 100
        ) > 15 THEN 1
        ELSE 0
    END AS spend_acceleration_flag

FROM ps_cloud_curated.fact_cost_monthly;


-- Sanity check
SELECT * FROM ps_cloud_curated.v_cost_trends
ORDER BY agency_id, date_key
LIMIT 10;


-- -----------------------------------------------------------------------------
-- 2. BUDGET RUN-RATE PROJECTION VIEW
--    Projects year-end spend per agency based on current monthly run rate.
--    This is a run-rate estimate, not a predictive model — it answers the
--    Finance Director's core question: "If we keep spending at this pace,
--    where do we land at fiscal year end?"
--
--    Note: Fiscal year assumed Jan–Dec. Adjust month boundaries for
--    T&T fiscal year (Oct–Sep) or other Caribbean fiscal calendars.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW ps_cloud_curated.v_budget_runrate AS
WITH monthly_totals AS (
    SELECT
        agency_id,
        date_key,
        CAST(year(date_key) AS VARCHAR)             AS fiscal_year,
        CAST(month(date_key) AS INT)                AS month_num,
        SUM(cost_usd)                               AS monthly_spend
    FROM ps_cloud_curated.fact_cost_monthly
    GROUP BY agency_id, date_key
),
ytd_totals AS (
    SELECT
        agency_id,
        fiscal_year,
        MAX(month_num)                              AS months_elapsed,
        SUM(monthly_spend)                         AS ytd_spend
    FROM monthly_totals
    GROUP BY agency_id, fiscal_year
)
SELECT
    agency_id,
    fiscal_year,
    months_elapsed,
    ytd_spend,

    -- Run-rate projection to year end (12 months)
    ROUND((ytd_spend / NULLIF(months_elapsed, 0)) * 12, 2)
        AS projected_annual_spend,

    -- Monthly average burn rate
    ROUND(ytd_spend / NULLIF(months_elapsed, 0), 2)
        AS avg_monthly_burn

FROM ytd_totals;


-- Sanity check
SELECT * FROM ps_cloud_curated.v_budget_runrate
ORDER BY agency_id, fiscal_year
LIMIT 10;


-- -----------------------------------------------------------------------------
-- 3. SEASONALITY INDEX VIEW
--    Measures how much each month's spend deviates from the agency's 
--    rolling average, identifying cyclical public-sector demand patterns
--    (e.g. tax season, budget cycles, renewal periods).
--
--    Index > 1.0 = above-average spend month (peak pressure)
--    Index < 1.0 = below-average spend month (baseline period)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW ps_cloud_curated.v_seasonality_index AS
WITH monthly_cost AS (
    SELECT
        agency_id,
        date_key,
        SUM(cost_usd) AS monthly_spend
    FROM ps_cloud_curated.fact_cost_monthly
    GROUP BY agency_id, date_key
)
SELECT
    agency_id,
    date_key,
    monthly_spend,

    -- 6-month rolling average as the baseline
    AVG(monthly_spend) OVER (
        PARTITION BY agency_id
        ORDER BY date_key
        ROWS BETWEEN 5 PRECEDING AND CURRENT ROW
    ) AS rolling_6m_avg,

    -- Seasonality index: actual vs rolling average
    ROUND(
        monthly_spend
        / NULLIF(
            AVG(monthly_spend) OVER (
                PARTITION BY agency_id
                ORDER BY date_key
                ROWS BETWEEN 5 PRECEDING AND CURRENT ROW
            ),
          0),
    3) AS seasonality_index,

    -- Flag months with index > 1.2 as high-pressure periods
    CASE
        WHEN monthly_spend / NULLIF(
            AVG(monthly_spend) OVER (
                PARTITION BY agency_id
                ORDER BY date_key
                ROWS BETWEEN 5 PRECEDING AND CURRENT ROW
            ), 0) > 1.2
        THEN 1 ELSE 0
    END AS high_pressure_flag

FROM monthly_cost;


-- Sanity check
SELECT * FROM ps_cloud_curated.v_seasonality_index
ORDER BY agency_id, date_key
LIMIT 10;


-- -----------------------------------------------------------------------------
-- 4. SLA BAND VIEW (Reliability - tiered thresholds)
--    Adds explicit RAG (Red/Amber/Green) banding to performance metrics,
--    making SLA status immediately interpretable in dashboards without
--    requiring DAX or Power BI calculated columns.
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW ps_cloud_curated.v_sla_bands AS
SELECT
    agency_id,
    date_key,
    service_id,
    region_id,
    migration_status,
    peak_period_flag,
    latency_ms,
    error_rate_pct,
    utilisation_pct,
    sla_breach_flag,

    -- Latency RAG band
    CASE
        WHEN latency_ms <= 250  THEN 'Green'
        WHEN latency_ms <= 500  THEN 'Amber'
        ELSE                         'Red'
    END AS latency_band,

    -- Error rate RAG band
    CASE
        WHEN error_rate_pct <= 1.0  THEN 'Green'
        WHEN error_rate_pct <= 3.0  THEN 'Amber'
        ELSE                             'Red'
    END AS error_band,

    -- Utilisation RAG band
    CASE
        WHEN utilisation_pct < 20               THEN 'Under-utilised'
        WHEN utilisation_pct BETWEEN 20 AND 85  THEN 'Healthy'
        ELSE                                         'High Risk'
    END AS utilisation_band,

    -- Composite service health score (0-100)
    -- Weighted: latency 40%, error rate 40%, utilisation 20%
    ROUND(
        (
            CASE
                WHEN latency_ms <= 250 THEN 100
                WHEN latency_ms <= 500 THEN 70
                ELSE 40
            END * 0.40
        ) +
        (
            CASE
                WHEN error_rate_pct <= 1.0 THEN 100
                WHEN error_rate_pct <= 3.0 THEN 70
                ELSE 40
            END * 0.40
        ) +
        (
            CASE
                WHEN utilisation_pct BETWEEN 20 AND 85 THEN 100
                WHEN utilisation_pct < 20              THEN 60
                ELSE                                        40
            END * 0.20
        ),
    1) AS composite_health_score

FROM ps_cloud_curated.fact_performance;


-- Sanity check
SELECT * FROM ps_cloud_curated.v_sla_bands
ORDER BY agency_id, date_key
LIMIT 10;
