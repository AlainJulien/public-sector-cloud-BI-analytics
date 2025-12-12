# Architecture Overview  
# Public-Sector Cloud BI Platform (AWS + Athena + Power BI)

This document describes the end-to-end architecture used to support two analytical narratives:
1. **Digital Service Reliability & Performance**
2. **FinOps — Budget Governance, Forecasting & Cloud Cost Optimization**

The architecture reflects the constraints and operating patterns commonly found in public-sector AWS environments, including restricted IAM permissions and limited use of automation.


## 1. High-Level Architecture
    Synthetic CSV - S3 (raw zone)
    - AWS Glue (manual DB + table definitions)
    - Athena (manual CREATE EXTERNAL TABLE for raw)
    - Athena CTAS (curated/star schema)
    - Power BI (Simba Athena ODBC)
    - Reliability + FinOps dashboards

##   Key principles:
    - Use S3 as the primary data lake layer.
    - Use Glue Data Catalog for metadata (DBs and some tables created manually).
    - Use Athena SQL for:
        - Raw table creation  
        - Data quality checks  
        - Curated data modeling (CTAS)  
        - Use Parquet format for curated analytics.
    - Connect Power BI directly to Athena using the ODBC driver.


## 2. Why a Hybrid Glue + Athena Approach?

In many government AWS accounts:
- Glue Crawlers are not permitted due to IAM boundary policies.
- Automated scanning of S3 is restricted.
- Manual metadata control is preferred for compliance.

Therefore, this project uses the following hybrid approach:

**Manual (Glue Console):**
- Create `ps_cloud_raw` and `ps_cloud_curated` databases.

**Manual (Athena):**
- Create raw tables via `CREATE EXTERNAL TABLE` pointing to each S3 folder.

**Automated (Athena CTAS):**
- Create curated dim/fact tables using SQL transformations.

This workflow is common in:
- Caribbean & LATAM ministries
- Shared Tenancy GovCloud setups
- Accounts where Glue Crawlers are blocked by SCPs or Guardrails


## 3. Data Flow

### Step 1 — Ingest (Synthetic Data) 
    Raw CSVs are uploaded to S3 under a defined structure:
    s3://public-sector-cloud-analytics-aj/sample-data/

    Each folder contains one CSV file.

### Step 2 — Register Raw Tables
    Athena external tables are created manually:
    CREATE EXTERNAL TABLE ps_cloud_raw.ps_cloud_raw_usage_monthly...
    LOCATION 's3://public-sector-cloud-analytics-aj/sample-data/usage_monthly/'

### Step 3 — Curated Layer (CTAS)
    Athena CTAS transforms raw data into optimized Parquet star-schema tables stored under:
    Example: s3://public-sector-cloud-analytics-aj/curated/fact_cost_monthly/


### Step 4 — Consumption Layer
    Power BI connects to Athena using the Simba ODBC driver.

    Dashboards are created for:
    - Reliability & Performance  
    - SLA Monitoring  
    - Migration Impact  
    - FinOps (Budget vs Actual, Forecasting, Waste, Provider Strategy)  


## 4. Architecture Diagram

A visual diagram is included in the `/diagrams` folder (add your PNG there):

[ Architecture Diagram Placeholder ]

You can export your architecture PNG from Notion or draw.io and place it here.


## 5. Future Enhancements

Possible improvements:
- Add proper partitioning (year/month) to curated tables.
- Introduce Glue Jobs for automated ingestion.
- Add Redshift Serverless for complex analytics.
- Integrate CUR (Cost & Usage Report) for real FinOps-grade data.
- Add QuickSight for multi-user dashboards.
