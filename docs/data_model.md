# Data Model — Star Schema Design  
**Public-Sector Cloud BI Platform (AWS + Athena)**

This document describes the dimensional model used to support both the **Reliability** and **FinOps** narratives.  
The design follows industry-standard Kimball principles adapted to cloud operational and financial data.

The model consists of:

- **4 Dimension Tables**  
- **4 Core Fact Tables**  
- **2 Supporting Fact Tables**  
- **2 Derived Analytical Views**

This structure supports scalable analytics across agencies, services, workloads, and time.

---

# 1. Dimensional Model Diagram

           dim_date
             |
           date_key
             |
             |------ fact_usage_monthly --------
             |------ fact_performance ----------
             |------ fact_cost_monthly ---------
             |------ fact_finance_governance ---
             |------ fact_provider_finance -----
             |
        dim_agency     dim_service      dim_region


A visual PNG of this schema can be found under `/diagrams/star_schema.png`.


# 2. Dimension Tables (Dims)

## 2.1 `dim_date`

| Column | Description |
|--------|-------------|
| date_key | YYYYMM integer key |
| date | Full date |
| month_name | Month name |
| year | Year |
| quarter | Quarter number |
| peak_period_flag | Boolean indicating seasonal workload peaks |

### Purpose:
- Provides consistent time hierarchy  
- Enables seasonal and peak vs non-peak analyses  
- Supports forecasting and monthly granularity  

## 2.2 `dim_agency`

| Column | Description |
|--------|-------------|
| agency_id | Unique identifier for a government agency |
| agency_name | Ministry, Department or Agency |
| country | Country in which the agency is based |
| sector_type | Ministry type (Finance, Health, Justice, etc.) |
| org_size | Size classification (Small/Medium/Large) |
| preferred_region | Preferred cloud region |

### Purpose:
- Enables multi-agency analysis  
- Supports chargeback/showback models  
- Incorporates geographic & sector context  

## 2.3 `dim_service`

| Column | Description |
|--------|-------------|
| service_id | Unique service/workload ID |
| service_type | IaaS, PaaS, SaaS classification |
| criticality | High/Medium/Low |
| application_group | Business grouping (Licensing, Payments, Tax Filing) |

### Purpose:
- Enables service-level reliability & cost analytics  
- Supports criticality-based SLA evaluation  
- Allows engineering teams to segment workloads  

## 2.4 `dim_region`

| Column | Description |
|--------|-------------|
| region_id | Cloud region key |
| aws_region | e.g., us-east-1, us-west-2 |
| region_group | Geographic grouping (US East, US West, LATAM, etc.) |

### Purpose:
- Analyzes performance variation across regions  
- Helps evaluate whether agencies are using optimal regions  
- Supports provider strategy comparisons  


# 3. Fact Tables (Core Facts)

## 3.1 `fact_usage_monthly`

**Grain:** One row per agency × service × month.

| Column | Description |
|--------|-------------|
| agency_id | FK to dim_agency |
| date_key | FK to dim_date |
| service_id | FK to dim_service |
| region_id | FK to dim_region |
| compute_hours | Monthly compute consumption |
| storage_gb | Storage usage |
| data_egress_gb | Outbound data |
| utilisation_pct | Utilisation score |
| resource_count | Number of active resources |
| cost_usd | Cost incurred |

### Purpose:
- Provides baseline for both Reliability and FinOps metrics  
- Supports trending, forecasting, and utilisation analytics  

## 3.2 `fact_performance`

**Grain:** One row per agency × service × month.

| Column | Description |
|--------|-------------|
| latency_ms | Avg latency |
| error_rate_pct | Avg error % |
| sla_breach_flag | SLA violation indicator |
| utilisation_pct | From usage fact |
| stability_score | Derived metric (0–100) |

### Purpose:
- Provides operational performance indicators  
- Enables SLA monitoring & executive reliability reporting

## 3.3 `fact_cost_monthly`

**Grain:** One row per agency × service × month.

| Column | Description |
|--------|-------------|
| cost_usd | Actual cloud spend |
| utilisation_pct | Used for waste estimation |
| cost_per_unit | Derived from cost / workload_units |
| resource_count | Number of active resources |

### Purpose:
- Central FinOps fact table  
- Drives cost dashboards, variance analysis, forecasting

## 3.4 `fact_finance_governance`

**Grain:** One row per agency × month.

| Column | Description |
|--------|-------------|
| tagged_pct | % of resources properly tagged |
| untagged_cost_usd | Cost without tags |
| governance_risk_flag | Boolean for compliance risk |

### Purpose:
- Supports tagging compliance & governance scoring  
- Helps identify expenditure that cannot be allocated


# 4. Supporting Fact Tables

## 4.1 `fact_provider_finance`

Tracks provider spend (AWS, Azure, GCP).

| Column | Description |
|--------|-------------|
| agency_id | FK |
| year | Year |
| cloud_provider | AWS / Azure / GCP |
| spend_usd | Annual spend |
| provider_share_pct | % share of total provider spend |

### Purpose:
- Supports multi-cloud strategy analysis  
- Identifies concentration risk  

## 4.2 `fact_migration_summary`

Compares pre vs post migration.

| Column | Description |
|--------|-------------|
| pre_migration_cost_usd | Before cloud |
| post_migration_cost_usd | After cloud |
| realised_savings_pct | (pre - post) / pre |
| sla_breaches_pre | Before migration |
| sla_breaches_post | After migration |

### Purpose:
- Supports cloud ROI reporting  
- Used by leadership to justify modernization  


# 5. Derived Analytical Views

## 5.1 `v_cost_spikes`

Calculates MoM growth and identifies spikes:

| Column | Description |
|--------|-------------|
| mom_growth_pct | Month-over-month % change |
| spike_flag | 1 if growth exceeds defined threshold |

Useful for:
- Alerting  
- Budget governance  
- Trend explanation  

## 5.2 `v_cloud_waste`

Identifies waste using low utilisation:

| Column | Description |
|--------|-------------|
| idle_cost_usd | Cost for utilisation < 20% |

Useful for:
- Optimisation opportunity identification  
- Executive waste summary  


# 6. Data Quality Rules & Assumptions

- Months must be present in `dim_date` for all fact rows  
- Foreign keys between dims/facts are enforced through Athena JOINs  
- Utilisation < 20% classified as idle for waste estimation  
- SLAs use fixed thresholds (e.g., latency > 400ms, error rate > 5%)  
- Missing tags count toward untagged cost  
- Provider data is annual and must be aggregated at year level  
- Curated tables stored as Parquet for performance  


# 7. Why This Model Works for Public Sector Analytics

- Supports **multi-agency**, **multi-service**, **multi-region** data  
- Enables both **financial** and **operational** BI in one model  
- Avoids crawling dependencies (important in restricted government accounts which is common in Caribbean public sector)  
- Clean star schema = fast Power BI performance  
- Easily extendable to Redshift or QuickSight  
- Mirrors AWS BI best practices  


# 8. Future Enhancements

- Add more granular facts (daily usage, hourly logs)  
- Partition curated tables by date for faster Athena scans  
- Add CUR (Cost & Usage Report) integration  
- Add dimensional hierarchies (ministry → department → agency → unit)  
- Introduce Slow Changing Dimensions (SCD) Type 2 modelling for agency changes  

