CREATE database ps_cloud_raw;

CREATE database ps_cloud_curated;

/* Table creations
Usage monthly table*/

DROP TABLE ps_cloud_raw_usage_monthly;

CREATE EXTERNAL TABLE ps_cloud_raw.ps_cloud_raw_usage_monthly (
    agency_id int,
    country string,
    country_code string,
    month string,
    service_type string,
    compute_hours double,
    storage_gb double,
    data_egress_gb double,
    utilisation_pct double,
    cost_usd double,
    aws_region string,
    migration_status string,
    resource_count int
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
    'separatorChar' = ',',
    'quoteChar'     = '"',
    'escapeChar'    = '\\'
)
STORED AS TEXTFILE
LOCATION 's3://public-sector-cloud-analytics-aj/sample-data/usage_monthly/'
TBLPROPERTIES (
    'skip.header.line.count' = '1');

--sanity check
SELECT * FROM ps_cloud_raw.ps_cloud_raw_usage_monthly LIMIT 5;

--Provider spend table
CREATE EXTERNAL TABLE IF NOT EXISTS ps_cloud_raw.ps_cloud_raw_provider_spend (
    agency_id int,
    country string,
    country_code string,
    year int,
    cloud_provider string,
    spend_usd double
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
    'separatorChar' = ',',
    'quoteChar'     = '"',
    'escapeChar'    = '\\'
)
STORED AS TEXTFILE
LOCATION 's3://public-sector-cloud-analytics-aj/sample-data/provider_spend/'
TBLPROPERTIES (
    'skip.header.line.count' = '1',
    'use.null.for.invalid.data' = 'true');
    
--sanity check
SELECT * FROM ps_cloud_raw.ps_cloud_raw_provider_spend LIMIT 5;

--Migration summary table
CREATE EXTERNAL TABLE IF NOT EXISTS ps_cloud_raw.ps_cloud_raw_migration_summary (
    agency_id int,
    country string,
    country_code string,
    org_size string,
    migrated string,
    migration_date string,
    pre_migration_cost_usd double,
    post_migration_cost_usd double,
    expected_savings_pct double,
    realized_savings_pct double,
    sla_breaches_pre int,
    sla_breaches_post int
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
    'separatorChar' = ',',
    'quoteChar'     = '"',
    'escapeChar'    = '\\'
)
STORED AS TEXTFILE
LOCATION 's3://public-sector-cloud-analytics-aj/sample-data/migration_summary/'
TBLPROPERTIES (
    'skip.header.line.count' = '1',
    'use.null.for.invalid.data' = 'true');

--sanity check
SELECT * FROM ps_cloud_raw.ps_cloud_raw_migration_summary LIMIT 5;