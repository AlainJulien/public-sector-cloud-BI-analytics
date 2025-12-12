# Use Case 1: Digital Service Reliability & Performance Tracking  
**AWS + Athena + Power BI**

This use case simulates how a government ministry monitors the reliability and performance of cloud-hosted digital services (licensing, tax filing).  
The goal is to understand how these services behave **before and after migration**, and how they perform during **peak periods** such as tax season.

This mirrors real demands of AWS Public Sector customers, where the priority is ensuring that citizen-facing applications remain stable and responsive.


# 1. Business Problem

After migrating key citizen services to AWS, the MDA asks:

### Key Questions:
- Are applications consistently meeting **SLA targets**?
- Does performance depend on **agency**, **service type**, or **region**?
- Are critical services reliable during **peak workload months**?
- Did reliability **improve post migration**?
- Which services represent the **highest engineering and operational risk**?


# 2. Data Used

This use case relies on the following curated tables:

### **Fact Tables**
- `fact_usage_monthly` — usage metrics per agency/service/month  
- `fact_performance` — latency, error_rate_pct, SLA breach flags, response_time_score  
- `fact_migration_summary` — pre/post cost & reliability metrics  

### **Dimension Tables**
- `dim_agency`  
- `dim_service`  
- `dim_region`  
- `dim_date` (includes `peak_period_flag`)

### **Derived Views**
- `v_cost_spikes` — month-over-month cost spikes  
- `v_cloud_waste` — low-utilisation resources (utilisation < 20%)


# 3. Reliability KPIs

### 3.1 Stability Score (0–100)
A composite metric balancing latency, error rate, and utilisation:

    Stability Score =
-    ( Response Time Score * 0.4 )
-        ( (100 - Error Rate %) * 0.3 )
-        ( Utilisation Score * 0.3 )


This provides a single reliability measure per service/month.


### 3.2 SLA Breach Rate
Percentage of records where latency or error thresholds exceed defined SLA.

### 3.3 Avg Latency (ms)
Time taken for API calls, user actions, or transactions.

### 3.4 Avg Error Rate (%)
Percentage of service calls resulting in 4xx or 5xx errors.

### 3.5 Peak vs Non-Peak Performance
Derived from `dim_date.peak_period_flag`.

### 3.6 Pre vs Post Migration Comparison
Pulled from `fact_migration_summary`.


# 4. SQL Transformations

This use case required a hybrid workflow due to Glue Crawler restrictions.

### **4.1 Raw Tables**
Created manually using Athena:

    sql
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

### Reliability fact tables
-   fact_usage_monthly example

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

# 5. Power BI Model Reliability Layer
        dim_date[date_key]     → fact_performance[date_key]
        dim_agency[agency_id]  → fact_performance[agency_id]
        dim_service[service_id]→ fact_performance[service_id]
        dim_region[region_id]  → fact_performance[region_id]

# 6. Dashboard
##  Reliability
### Executive Overview
    Key visuals:
        Stability Score (card)
        SLA Breach Rate (card)
        Average Latency & Error Rate
        Stability trend (line chart)
        “Top Risk Services” table

### SLA & Engineering Details
### For use by CloudOps / Dev/ICT teams
    Key visuals:
        Latency breaches
        Error breaches
        Utilisation score
        Engineering risk score
        Latency vs Utilisation scatter
        Detailed root-cause table by agency & service

### Peak vs Non-Peak Load Analysis
    Key visuals:
        Peak vs Non-Peak stability
        Peak vs Non-Peak latency
        SLA breach concentration
        Seasonal load patterns

### Migration Impact Analysis
    Key visuals:
        Pre vs Post latency, error rate, SLA breaches
        Cost vs reliability trade-off (scatter plot)
        Migration summary table

### Insights Gained
-   Some agencies show better stability and lower SLA breaches post migration
-   A few agencies carry high engineering risks due to: under-utilized resources, low tagging compliance
-   Opportunities exist for auto-scaling, caching, service refactoring