--Fact tables

Drop table fact_usage_monthly;

CREATE TABLE ps_cloud_curated.fact_usage_monthly
WITH (
  format = 'PARQUET',
  external_location = 's3://public-sector-cloud-analytics-aj/curated/fact_usage_monthly/'
) AS
SELECT
  u.agency_id,
  d.date_key,
  s.service_id,
  r.region_id,
  u.service_type,
  u.compute_hours,
  u.storage_gb,
  u.data_egress_gb,
  u.utilisation_pct,
  u.cost_usd,
  u.resource_count,
  u.migration_status,
  u.aws_region
FROM ps_cloud_raw.ps_cloud_raw_usage_monthly u
LEFT JOIN ps_cloud_curated.dim_agency a
  ON u.agency_id = a.agency_id
LEFT JOIN ps_cloud_curated.dim_service s
  ON u.service_type = s.service_type
LEFT JOIN ps_cloud_curated.dim_region r
  ON u.aws_region = r.aws_region
LEFT JOIN ps_cloud_curated.dim_date d
  ON date_parse(u.month || '-01', '%Y-%m-%d') = d.date_key;
  
--sanity check
SELECT * FROM ps_cloud_curated.fact_usage_monthly LIMIT 5;

drop table fact_migration_summary;

--fact migration summary
CREATE TABLE ps_cloud_curated.fact_migration_summary
WITH (
  format = 'PARQUET',
  external_location = 's3://public-sector-cloud-analytics-aj/curated/fact_migration_summary/'
) AS
SELECT
  m.agency_id,
  a.country,
  a.country_code,
  a.org_size,
  CASE WHEN m.migrated = 'Yes' THEN 1 ELSE 0 END AS migration_flag,
  TRY(date_parse(NULLIF(m.migration_date, ''), '%d/%m/%Y')) AS migration_date,
  m.pre_migration_cost_usd,
  m.post_migration_cost_usd,
  m.expected_savings_pct,
  m.realized_savings_pct,
  m.sla_breaches_pre,
  m.sla_breaches_post,
  (m.post_migration_cost_usd - m.pre_migration_cost_usd) AS cost_delta_usd
FROM ps_cloud_raw.ps_cloud_raw_migration_summary m
LEFT JOIN ps_cloud_curated.dim_agency a
  ON m.agency_id = a.agency_id;

--sanity check
SELECT * FROM ps_cloud_curated.fact_migration_summary LIMIT 5;


--fact tagging compliance
CREATE TABLE ps_cloud_curated.fact_tagging_compliance
WITH (
  format = 'PARQUET',
  external_location = 's3://public-sector-cloud-analytics-aj/curated/fact_tagging_compliance/'
) AS
SELECT
  t.agency_id,
  d.date_key,
  t.tagged_pct,
  t.untagged_cost_usd
FROM ps_cloud_raw.ps_cloud_raw_tagging_compliance t
LEFT JOIN ps_cloud_curated.dim_date d
  ON date_parse(t.month || '-01', '%Y-%d-%m') = d.date_key;

--sanity check
SELECT * FROM ps_cloud_curated.fact_tagging_compliance LIMIT 5;


--fact provider spend
CREATE TABLE ps_cloud_curated.fact_provider_spend
WITH (
  format = 'PARQUET',
  external_location = 's3://public-sector-cloud-analytics-aj/curated/fact_provider_spend/'
) AS
SELECT
  p.agency_id,
  p.country,
  p.country_code,
  p.year,
  p.cloud_provider,
  p.spend_usd,
  p.spend_usd / SUM(p.spend_usd) OVER (PARTITION BY p.agency_id, p.year) AS provider_share_pct
FROM ps_cloud_raw.ps_cloud_raw_provider_spend p;

--sanity check
SELECT * FROM ps_cloud_curated.fact_provider_spend LIMIT 5;


--fact performance
CREATE TABLE ps_cloud_curated.fact_performance
WITH (
  format = 'PARQUET',
  external_location = 's3://public-sector-cloud-analytics-aj/curated/fact_performance/'
) AS
SELECT
  f.agency_id,
  f.date_key,
  f.service_id,
  f.region_id,
  f.service_type,
  f.migration_status,
  f.compute_hours,
  f.storage_gb,
  f.data_egress_gb,
  f.utilisation_pct,
  f.cost_usd,
  f.resource_count,
  d.peak_period_flag,

  -- Latency model (synthetic)
  (150
   + (f.utilisation_pct * 3)
   + CASE WHEN f.migration_status = 'Pre' THEN 80 ELSE 40 END
  ) AS latency_ms,

  -- Error rate model (synthetic)
  CASE
    WHEN f.utilisation_pct > 80 THEN 3.5
    WHEN f.utilisation_pct > 70 THEN 2.0
    ELSE 0.8
  END
  + CASE WHEN f.migration_status = 'Pre' THEN 0.7 ELSE 0.0 END
  AS error_rate_pct,

  -- SLA breach flag
  CASE
    WHEN (150 + (f.utilisation_pct * 3)
          + CASE WHEN f.migration_status = 'Pre' THEN 80 ELSE 40 END) > 500
      OR (CASE
             WHEN f.utilisation_pct > 80 THEN 3.5
             WHEN f.utilisation_pct > 70 THEN 2.0
             ELSE 0.8
          END
          + CASE WHEN f.migration_status = 'Pre' THEN 0.7 ELSE 0.0 END) > 3
      OR f.utilisation_pct > 85
    THEN 1 ELSE 0
  END AS sla_breach_flag,

  -- Response time score
  CASE
    WHEN (150 + (f.utilisation_pct * 3)
          + CASE WHEN f.migration_status = 'Pre' THEN 80 ELSE 40 END) <= 250
      THEN 100
    WHEN (150 + (f.utilisation_pct * 3)
          + CASE WHEN f.migration_status = 'Pre' THEN 80 ELSE 40 END) <= 500
      THEN 70
    ELSE 40
  END AS response_time_score,

  -- Efficiency ratio
  CASE WHEN f.cost_usd > 0 THEN f.utilisation_pct / f.cost_usd ELSE NULL END AS efficiency_ratio

FROM ps_cloud_curated.fact_usage_monthly f
LEFT JOIN ps_cloud_curated.dim_date d
  ON f.date_key = d.date_key;

--sanity check
SELECT * FROM ps_cloud_curated.fact_performance LIMIT 5;


--fact cost monthly
CREATE TABLE ps_cloud_curated.fact_cost_monthly
WITH (
  format = 'PARQUET',
  external_location = 's3://public-sector-cloud-analytics-aj/curated/fact_cost_monthly/'
) AS
SELECT
    u.agency_id,
    d.date_key,
    s.service_id,
    r.region_id,
    u.service_type,
    u.cost_usd,
    u.compute_hours,
    u.storage_gb,
    u.data_egress_gb,
    u.utilisation_pct,
    u.resource_count,
    u.migration_status,

    -- Derived: Cost per workload unit (simple normalisation)
    CASE 
        WHEN (u.compute_hours + u.storage_gb + u.data_egress_gb) > 0
        THEN u.cost_usd / 
             (u.compute_hours
              + (u.storage_gb * 0.05)
              + (u.data_egress_gb * 0.5))
        ELSE NULL
    END AS cost_per_unit

FROM ps_cloud_raw.ps_cloud_raw_usage_monthly u
LEFT JOIN ps_cloud_curated.dim_agency a
  ON u.agency_id = a.agency_id
LEFT JOIN ps_cloud_curated.dim_date d
  ON date_parse(u.month || '-01', '%Y-%m-%d') = d.date_key
LEFT JOIN ps_cloud_curated.dim_service s
  ON u.service_type = s.service_type
LEFT JOIN ps_cloud_curated.dim_region r
  ON u.aws_region = r.aws_region;

--sanity check 
SELECT * FROM ps_cloud_curated.fact_cost_monthly LIMIT 5;


--fact finance governance (tagging, untagged, cost, risk flags)
CREATE TABLE ps_cloud_curated.fact_finance_governance
WITH (
  format = 'PARQUET',
  external_location = 's3://public-sector-cloud-analytics-aj/curated/fact_finance_governance/'
) AS
SELECT
    t.agency_id,
    d.date_key,
    t.tagged_pct,
    t.untagged_cost_usd,

    -- Tagging gap (how far from 100%)
    (100 - t.tagged_pct) AS tagging_gap,

    -- Governance risk flag (<80% tagged)
    CASE
        WHEN t.tagged_pct < 80 THEN 1
        ELSE 0
    END AS governance_risk_flag

FROM ps_cloud_raw.ps_cloud_raw_tagging_compliance t
LEFT JOIN ps_cloud_curated.dim_date d
  ON date_parse(t.month || '-01', '%Y-%m-%d') = d.date_key;

--sanity check 
SELECT * FROM ps_cloud_curated.fact_finance_governance LIMIT 5;


--fact provider finance (multicloud spend + provider share)
CREATE TABLE ps_cloud_curated.fact_provider_finance
WITH (
  format = 'PARQUET',
  external_location = 's3://public-sector-cloud-analytics-aj/curated/fact_provider_finance/'
) AS
SELECT
    p.agency_id,
    p.country,
    p.country_code,
    p.year,
    p.cloud_provider,
    p.spend_usd,

    -- Provider share % within agency+year
    p.spend_usd 
      / SUM(p.spend_usd) OVER (PARTITION BY p.agency_id, p.year)
        AS provider_share_pct

FROM ps_cloud_raw.ps_cloud_raw_provider_spend p;

--sanity check 
SELECT * FROM ps_cloud_curated.fact_provider_finance LIMIT 5;


--fact forecast input(time series for prediction, aggregate monthly cost and add a month index for regression)
CREATE TABLE ps_cloud_curated.fact_forecast_input
WITH (
  format = 'PARQUET',
  external_location = 's3://public-sector-cloud-analytics-aj/curated/fact_forecast_input/'
) AS
SELECT
    agency_id,
    date_key,
    SUM(cost_usd) AS monthly_cost,
    ROW_NUMBER() OVER (PARTITION BY agency_id ORDER BY date_key) AS month_index
FROM ps_cloud_curated.fact_cost_monthly
GROUP BY agency_id, date_key
ORDER BY agency_id, date_key;

--sanity check 
SELECT * FROM ps_cloud_curated.fact_forecast_input LIMIT 5;



--Cost spikes and waste views
--Cost spike view
CREATE OR REPLACE VIEW ps_cloud_curated.v_cost_spikes AS
SELECT
    agency_id,
    date_key,
    cost_usd,
    spend_growth_pct,
    CASE WHEN spend_growth_pct > 0.25 THEN 1 ELSE 0 END AS spike_flag
FROM (
    SELECT
        agency_id,
        date_key,
        cost_usd,
        (cost_usd - LAG(cost_usd) OVER (PARTITION BY agency_id ORDER BY date_key))
        / NULLIF(LAG(cost_usd) OVER (PARTITION BY agency_id ORDER BY date_key), 0)
          AS spend_growth_pct
    FROM ps_cloud_curated.fact_cost_monthly);


--sanity check
SELECT * FROM ps_cloud_curated.v_cost_spikes LIMIT 5;

--Waste view 
CREATE OR REPLACE VIEW ps_cloud_curated.v_cloud_waste AS
SELECT
    agency_id,
    date_key,
    cost_usd,
    utilisation_pct,
    CASE WHEN utilisation_pct < 20 THEN cost_usd ELSE 0 END AS idle_cost,
    CASE WHEN utilisation_pct < 20 THEN 1 ELSE 0 END AS idle_flag
FROM ps_cloud_curated.fact_cost_monthly;


--sanity check
SELECT * FROM ps_cloud_curated.v_cloud_waste LIMIT 5;

