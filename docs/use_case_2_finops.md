# Use Case 2: FinOps — Budget Governance, Forecasting & Cloud Cost Optimization  
**AWS + Athena + Power BI**

This use case simulates the financial oversight challenges faced by a public-sector ministry operating cloud workloads across multiple agencies. The aim is to ensure spend predictability, enforce tagging governance, identify waste, and support decision-making for multi-cloud procurement.


# 1. Business Problem

Government cloud spend grows unpredictably due to:
- Variable monthly consumption  
- Multiple agencies consuming cloud resources  
- Lack of proper tagging  
- Idle or underused infrastructure  
- Multi-cloud fragmentation  

Leadership asks:

### **Key Questions**
- Are we staying within our **annual and monthly budgets**?  
- What caused this month’s **cost spike**?  
- Which agencies or services are driving **overspend**?  
- How much of our spend is **waste** (idle resources)?  
- How much cost cannot be allocated due to **missing tags**?  
- What is our dependency on **AWS vs Azure vs GCP**?  
- Can we **forecast** next quarter’s spend?

This use case answers all of the above.


# 2. Data Used

### **FinOps Fact Tables**
- `fact_cost_monthly` — usage-based cost data with utilisation metrics  
- `fact_finance_governance` — tagging compliance & untagged cost  
- `fact_provider_finance` — AWS/Azure/GCP spend by agency/year  
- `fact_forecast_input` — historical time series for forecasting  

### **Dimensions**
- `dim_agency`  
- `dim_date`  
- `dim_service`  
- `dim_region`

### **Derived Views**
- `v_cost_spikes` — MoM spend spikes  
- `v_cloud_waste` — idle cost estimation  


# 3. KPIs & Financial Metrics

## 3.1 Actual Spend
Pulled from `fact_cost_monthly.cost_usd`.

## 3.2 Budget vs Actual (BvA)
A manually defined budget table in Power BI maps monthly budget allocations to agencies.
Formulas used:
    Budget Spend = SUM(Budget[Monthly Budget USD])
    Variance USD = Actual Spend - Budget Spend
    Variance % = (Actual - Budget) / Budget

This supports:
- Monthly variance tracking  
- YTD variance  
- Agency-level budget adherence  

## 3.3 Spend Forecast
Using Power BI’s built-in forecasting model applied to `[Actual Spend]`:

- 3–6 month forecast  
- Confidence intervals (80–95%)  
- Seasonal trend detection (Not Applicable to the Caribbean but used for demo purposes)  

This approximates cost planning for quarterly budget cycles.

## 3.4 Tagging & Governance Metrics

### Tagged %
    Weighted Tagged % = AVERAGE(fact_finance_governance[tagged_pct])

### Untagged Cost  
Cost that cannot be allocated to any cost center or ministry:
    Total Untagged Cost = SUM(fact_finance_governance[untagged_cost_usd])

### Untagged % of Spend
    Untagged % of Spend = Total Untagged Cost / Actual Spend

### Governance Risk Flag  
A binary indicator used by compliance teams: governance_risk_flag = 1 if tagged_pct < 80

This reflects AWS FinOps best practice (80% tagging minimum).

## 3.5 Waste / Idle Cost

Idle cost is estimated using utilisation < 20%:
    Idle Cost = SUMX(
                fact_cost_monthly,
                IF(fact_cost_monthly[utilisation_pct] < 20, fact_cost_monthly[cost_usd], 0)
                )

This simulates:
-   Overprovisioned compute  
-   Idle storage  
-   Underutilised databases  
-   Forgotten dev/test environments  

In AWS terms, this is known as the **“Low-Utilisation Opportunity”**.

## 3.6 Provider Strategy Metrics

### Provider Spend  
From `fact_provider_finance`:
    AWS Spend = CALCULATE([Total Provider Spend], provider="AWS")
    Azure Spend = CALCULATE([Total Provider Spend], provider="Azure")
    GCP Spend = CALCULATE([Total Provider Spend], provider="GCP")

### Provider Share (Concentration Risk)
    AWS Share % = AWS Spend / Total Provider Spend

This is used to detect overdependence or fragmentation across cloud vendors.


# 4. SQL Transformations (Hybrid Method)

Due to IAM policy restrictions, Glue Crawlers were not used.  
Instead:

## **4.1 Raw Layer — Manual Table Creation**

Raw cost files were mapped manually:

sql
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

## Curated facts and dims made sing Athena CTAS
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

# 5. Power BI Model (FinOps)
    dim_date[date_key] → fact_cost_monthly[date_key]
    dim_agency[agency_id] → fact_cost_monthly[agency_id]
    dim_agency[agency_id] → fact_finance_governance[agency_id]
    dim_agency[agency_id] → fact_provider_finance[agency_id]

## Additional Tables:
    Budget (manual for portfolio purposes) & Opportunity Categories (chart optimization)

## Measures covered
    Spend, Variance, YTD performance, Idle cost, Waste %, Tagged %, Provider distribution


# 6. Dashboard
##  FinOps
###  Budget Overview
     YTD spend vs budget
     Variance (USD & %)
     Budget vs Actual monthly trend
     Agency-level budget adherence

###  Cost & Trends & Forecasting
     Actual spend trend
     3–6 month forecast
     MoM spend growth
     Service mix evolution (IaaS/PaaS/SaaS)
     Top growth agencies

###  Governance & Waste
     Tagged % trend
     Untagged cost by agency
     Idle cost by service
     Governance risk (flag)
     Waste % of spend
     Combined optimization opportunities (untagged + idle + high-risk spend)

### Provider Spend
    Spend by AWS/Azure/GCP
    Provider share %
    Agency-level dependency
    Concentration risk visuals

### Insights Gained
-   Budget Governance: several MDAs overspent on a YTD basis *input %*
                     : Forecast indicates possible budget issues in Q3 if no intervention is done
-   Waste & Optimization: Significant spend is linked to Idle resources 
                        : Untagged costs leads to reduced financial transparency and weakens chargeback (resources paid for by departments or agencies) / showback (IT/cloud cost presented to BUs) models
-   Provider Strategy: High concentration risk as some MDAs are rely heavily on AWS
                     : Some MDAs show multi-clod fragmentation which can lead to complex governance

If budget variance, waste %, untagged cost and high-risk spend are looked at together, you can create a financial risk ranking