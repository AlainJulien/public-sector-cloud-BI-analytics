--Curated tables

--skip headers for glue tables
ALTER TABLE ps_cloud_raw.ps_cloud_raw_agencies
SET TBLPROPERTIES (
  'skip.header.line.count' = '1'
);

ALTER TABLE ps_cloud_raw.ps_cloud_raw_baseline_adoption
SET TBLPROPERTIES (
  'skip.header.line.count' = '1'
);

ALTER TABLE ps_cloud_raw.ps_cloud_raw_tagging_compliance
SET TBLPROPERTIES (
  'skip.header.line.count' = '1'
);

ALTER TABLE ps_cloud_raw.ps_cloud_raw_provider_spend
SET TBLPROPERTIES (
  'skip.header.line.count' = '1'
);


--dim agency clean
CREATE TABLE ps_cloud_curated.dim_agency_clean
WITH (
  format = 'PARQUET',
  external_location = 's3://public-sector-cloud-analytics-aj/curated/dim_agency_clean/'
) AS
SELECT
  agency_id,
  max(agency_name)      AS agency_name,
  max(country)          AS country,
  max(country_code)     AS country_code,
  max(org_size)         AS org_size,
  max(sector_type)      AS sector_type,
  max(aws_pref_region)  AS aws_pref_region,
  max(currency)         AS currency,
  max(region_group)     AS region_group
FROM ps_cloud_raw.ps_cloud_raw_agencies
GROUP BY agency_id;

--sanity check
SELECT * FROM ps_cloud_curated.dim_agency_clean LIMIT 10;


DROP TABLE IF EXISTS ps_cloud_curated.dim_service;

--dim service
CREATE TABLE ps_cloud_curated.dim_service
WITH (
  format = 'PARQUET',
  external_location = 's3://public-sector-cloud-analytics-aj/curated/dim_service/'
) AS
SELECT *
FROM (
  VALUES
    (1, 'IaaS', 'Compute Infrastructure', 'High'),
    (2, 'PaaS', 'Platform Services',      'Medium'),
    (3, 'SaaS', 'Application Services',   'High')
) AS t(service_id, service_type, service_name, criticality_level);

--sanity check
SELECT * FROM ps_cloud_curated.dim_service LIMIT 10;


DROP TABLE IF EXISTS ps_cloud_curated.dim_region;

--dim region
CREATE TABLE ps_cloud_curated.dim_region
WITH (
  format = 'PARQUET',
  external_location = 's3://public-sector-cloud-analytics-aj/curated/dim_region/'
) AS
SELECT DISTINCT
  ROW_NUMBER() OVER (ORDER BY aws_pref_region) AS region_id,
  aws_pref_region        AS aws_region,
  region_group,
  'Primary'              AS tier
FROM ps_cloud_raw.ps_cloud_raw_agencies;

--sanity check
SELECT * FROM ps_cloud_curated.dim_region LIMIT 10;


DROP TABLE IF EXISTS ps_cloud_curated.dim_date;

--dim date
CREATE TABLE ps_cloud_curated.dim_date
WITH (
  format = 'PARQUET',
  external_location = 's3://public-sector-cloud-analytics-aj/curated/dim_date/'
) AS
SELECT
  date_parse(month || '-01', '%Y-%m-%d')             AS date_key,
  substr(month, 1, 4)                                AS year,
  substr(month, 6, 2)                                AS month,
  concat(substr(month, 1, 4), '-Q',
         cast(((cast(substr(month, 6, 2) AS INT) - 1) / 3 + 1) AS VARCHAR)) AS quarter,
  CASE
    WHEN substr(month, 6, 2) IN ('01','02','03','07','08','09') THEN 1
    ELSE 0
  END AS peak_period_flag
FROM (
  SELECT DISTINCT month FROM ps_cloud_raw.ps_cloud_raw_usage_monthly);

--sanity check
SELECT * FROM ps_cloud_curated.dim_date LIMIT 10;
