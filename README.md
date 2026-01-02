# Public-Sector Cloud BI Analytics
## Reliability, Performance & Cost Governance
<p align="center">
  <img src="screenshots/architecture_overview.png" width="80%" alt="Architecture Diagram">
</p>

<p align="center">
  <strong>Architecture Overview – AWS Lakehouse + Power BI</strong>
</p>

A business intelligence solution that evaluates post-migration cloud reliability, performance behavior, and financial governance across public-sector workloads.

# 1. Project Overview
    This project delivers an end-to-end cloud analytics capability designed for public-sector ministries and agencies operating in constrained, budget-driven environments.

    The solution enables leadership and technical teams to:
        - Assess digital service reliability after cloud migration
        - Compare peak vs non-peak performance behavior
        - Monitor budget vs actual spend and forecast future costs
        - Enforce FinOps governance through tagging and waste analysis
        - Identify engineering and financial risk hotspots across agencies

    The project reflects real-world public-sector constraints, including limited IAM permissions and governance requirements, while demonstrating practical BI engineering patterns.

    Technology Stack used:
    Data Platform: Amazon S3, AWS Glue (metadata), Amazon Athena
    Data Modeling: Star Schemas (dimensions, fact tables, CTAS)
    Analytics & Visualizaton: Power BI
    Domain Covered: Service reliability, performance engineering, FinOPs governance


# 2. Business Narratives
   a. Narrative 1 - Digital Service Reliability & Performance
                    This narrative evaluates whether cloud-migrated public services remain stable, performant, and resilient under peak demand.
                    
                    - Key Questions from Leadership to be answered:
                        a. Are critical services reliable during peak periods e.g. tax times?
                        b. Did reliability improve post migration? 
                        c. Which services/MDAs generate the most SLA breaches, latency or errors?
                        d. How do utilization and cost patterns correlate with reliability risk?
                    
                    - Analytical focus:
                        a. Pre vs Post migration Latency, Error rate and SLA Breaches
                        b. Non-peak vs Peak performance
                        c. Service Risk ranking across agencies and regions
                        d. Relationship between utilisation, cost and reliability

   b. Narrative 2 - FinOps — Budget Governance, Forecasting & Cloud Cost Optimization
                    This narrative addresses cloud cost volatility, attribution challenges, and governance gaps common in public-sector cloud adoption.

                    - Key Questions from MDAs to be answered:
                        a. How does actual spend compare to assigned budgets? 
                        b. Which agencies show recurring cost overruns or inefficient growth?
                        c. Where do tagging gaps reduce financial transparency?
                        d. What idle or under-utilized resources represent avoidable waste?
                        e. What provider concentration or multi-cloud risks exist?
                    
                    - Analytical focus:
                        a. Budget vs actual spend and variance tracking
                        b. Spending patterns and forecasts
                        c. Tagging compliance & untagged cost exposure
                        d. Idle resource identification and optimization opportunities
                        e. Cloud provider spend concentration


# 3. Architecture Overview
    This projct uses a hybrid Glue & Athena architecture, reflecting account-level IAM constraints commonly encountered in public-sector environments.

## Architecture Diagram

<p align="center">
  <img src="screenshots/architecture_overview.png" width="70%" alt="Architecture Diagram">
</p>


    Logical flow:   
        S3: Raw and curated synthetic datasets
        AWS Glue: Manual database creation and table definitions
        Amazon Athena: SQL-based transformations and CTAS modeling
        Power BI: Analytical and executive dashboards


# 4. Data Model / Star Schemas
## Star Schema

<p align="center">
  <img src="screenshots/star_schema.png" width="70%" alt="Star Schema Diagram">
</p>


    All data used for this project has been synthetically generated to reflect that of AWS public-sector cloud usage while reflecting the organizational structure and constraints of Caribbean Ministries, Departments, and Agencies (MDAs).

        Core Datasets (Raw)
            agencies.csv – list of ministries / agencies (country, org size, preferred region)
            baseline_adoption.csv – basic cloud maturity context
            usage_monthly.csv – monthly usage & cost per agency/service/region
            provider_spend.csv – annual spend by provider (AWS, Azure, GCP)
            migration_summary.csv – pre/post migration cost & SLA info
            tagging_compliance.csv – tagging % and untagged cost over time
        
        Curated Athena CTAS (S3/curated/)
        Dimensions: dim_agency – agency, country, sector type, org size, preferred AWS region
                    dim_date – month-level calendar with peak_period_flag
                    dim_service – service category (IaaS / PaaS / SaaS, criticality)
                    dim_region – AWS region + regional grouping
        
        Fact Tables
        Reliability: fact_usage_monthly – usage & cost per agency/service/month
                     fact_performance – derived latency, error_rate_pct, SLA breach flags, response_time_score
                     fact_migration_summary – pre/post migration cost, realised savings %, SLA change
        
        FinOps: fact_cost_monthly – cost, utilisation, workload units, cost_per_unit
                fact_finance_governance – tagging %, untagged_cost_usd, governance_risk_flag
                fact_provider_finance – provider-level spend & provider_share_pct
                fact_forecast_input – monthly_cost time series per agency for forecasting
        
        Derived Views: v_cost_spikes – month-over-month spend growth & spike flags
                       v_cloud_waste – idle_cost based on utilisation < 20%


    Reliability Star Schema:

               dim_date
                  |
                  |
       dim_agency ---- dim_service ---- dim_region
                  \       |      /
                   \      |     /
                   fact_usage_monthly
                         |
                         |
               fact_performance
                         |
         fact_migration_summary ---- dim_cost_category
                         |
                 fact_tagging_compliance
                         |
                 fact_provider_spend

    Finance Star Schema:

                    dim_date
                        |
                        |
         dim_agency -- fact_cost_monthly -- dim_service
                        |
                 fact_tagging_compliance
                        |
                 fact_provider_spend
                        |
                 dim_cloud_provider


# 6. SQL Models
    RAW Layer
    This layer stores original, unaltered copies of the datasets simulated for this project in the S3 bucket that are queried in Athena but no transformations are applied to the originals. Due to IAM restrictions on the account, below is an example that shows the manual table creation for the raw data:
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
    
    Curated Layer
    This layer turns raw datasets into analysis-ready tables. It involves normalization, filtering, deriving of metrics and identification of keys for joins. This layer was fully generated using Athena e.g.:
    --Dim agency
        CREATE TABLE ps_cloud_curated.dim_agency
        WITH (
            format = 'PARQUET',
            external_location = 's3://public-sector-cloud-analytics-aj/curated/dim_agency/'
        ) AS
        SELECT
            agency_id,
            agency_name,
            country,
            country_code,
            org_size,
            sector_type,
            aws_pref_region,
            currency,
            region_group
        FROM ps_cloud_raw.ps_cloud_raw_agencies;

    --sanity check
    SELECT * FROM ps_cloud_curated.dim_agency LIMIT 10;

    It also created the Dimensions: dim_date, dim_region, dim_services, dim_agency_clean.

    GOLD layers
    This layer contains business centered fact tables that support the BI story. All key metrics and flags are calcualted and ready for visualization e.g.:
     --Fact usage monthly
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

     Here the Reliability and FinOps fact tables were created: fact_performance, fact_migration_summary, fact_cost_monthly, fact_finance_governance, fact_provider_finance, fact_forecast_input. Basic views were derived as well; v_cost_spikes, v_cloud_waste for optics in the event of leadership ask.


# 7. Dashboards
    Power BI connected to Athena via Amazon Athena ODBC driver to load data from the S3 bucket.

    Reliability Dashboard
    - Executive Overview: Stability Score (0-100), SLA Breach Rate %, Avrage Latency & Error Rat, Stability trend over time, Top Risk Services table

    - SLA & Performance: Engineering KPIs (latency breaches, error breaches, utilisation score), SLA breach trends, Latency vs utilisation scatter (stress hotspots), Root-cause table for engineering teams

    - Peak vs Non-Peak Stress Analysis: Peak vs Non-Peak stability and latency, Peak-only SLA trends, Agencies/services that collapse under peak load

    - Migration Impact Assessment: Pre vs Post stability, latency, and SLA breaches, Migration summary by agency (cost_delta_usd, realised_savings_pct), Scatter of cost_delta vs stability_delta (cloud ROI vs reliability)

    FinOps Dashboards
    - Budget Oversight with Variance indicators: YTD Actual vs Budget, YTD Variance % (Green/Yellow/Red), Budget vs Actual over time, Agency-level variance table

    - Cost Trends & Forecast projections: Monthly spend trend + Power BI forecast, MoM Spend Growth %, Rolling 3-month spend, Service mix over time (IaaS / PaaS / SaaS), Top-growth agencies table

    - Tagging compliance and Waste analysis: Tagged % and governance risk count, Untagged Cost and Waste % (idle cost), Agency-level governance heat table, Waste by service and agency

    - Cloud Provider Strategy & concentration risk: Spend by provider (AWS / Azure / GCP) over time, Provider share % per agency, Concentration risk view (e.g. AWS share by agency)

    A dedicated executive summary page consolidates financial and reliability signals into a single, decision-ready view.


# 8. Key Insights (sample)
        - Post-migration stability improved across several critical services, with a measurable reduction in SLA breaches
        - A small number of agencies account for a disproportionate share of cloud spend
        - Untagged costs materially reduce financial transparency and weaken chargeback models
        - Idle or under-utilized resources represent significant, avoidable annual waste
        - Forecasting indicates potential budget overruns without early optimization actions
    

# 9. Recommendations
    - Strengthen tagging governance and enforcement policies
    - Introduce rolling cost forecasts and quarterly review cycles
    - Rightsize under-utilized workloads
    - Implement cost anomaly detection
    - Increase managed service (PaaS) adoption to reduce IaaS overhead


# 10. How to Run this Project
    - Prerequisites: AWS account with S3, Glue and Athena access, Power BI Desktop (free), Ahtena ODBC driver (to connect S3 to Power Bi)
        1. Clone Repository
        2. Create / Upload raw files into S3
        3. Create manual Databases in Glue and manually create 3 raw tables (for learning or can just create all in Athena)
        4. Create & execute scripts for manual raw table creation & CTAS within Athena to build dimensions, facts and views 
        5. Use the Athena ODBC driver and configure DSN (install ODBC driver if needed). Open PowerBI, connect to Athena and import curated tables from ps_cloud_curated and Power Bi auto determines relationships (double check for accuracy). Build any DAX measures needed after loading.

# 11. Repository Structure
        
        - dashboards/         # Power BI files (reliability + FinOps)
        - data/               # Sample raw/curated data (if included)
        - diagrams/           # Architecture + star schema diagrams
        - docs/               # Detailed write-ups for each use case
        - screenshots/        # PNGs used in README / portfolio
        - sql/                # Athena CTAS + view definitions
        - README.md           # This file


# 12. Skills Demonstrated & Learned
    a. BI Engineering (Dimensions, fact tables, CTAS pipelines)
    b. Data Modeling (Star Schemas)
    c. AWS analytics services (S3, Glue, Athena)
    d. SQL transformation and metric design
    e. Power BI (Data modeling, DAX measures, executive & engineering dashboards)
    f. FinOps Governance and cost analytics
    g. Public-Sector data and governance considerations


# 13. About the Author
    Business Systems Analyst transitioning into Business Intelligence, with hands-on experience building end-to-end analytics projects focused on cloud migration, service reliability, and cost governance in public-sector environments. This project represents applied BI engineering work using AWS analytics services and Power BI.


#   Dashboard Gallery

### Reliability – Executive Overview
<p align="center">
  <img src="screenshots/reliability_exec_overview.png" width="85%" alt="Reliability Executive Dashboard">
</p>

### FinOps – Executive Summary
<p align="center">
  <img src="screenshots/finops_exec_summary.png" width="85%" alt="FinOps Executive Dashboard">
</p>