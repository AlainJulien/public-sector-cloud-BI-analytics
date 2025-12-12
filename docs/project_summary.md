# Project Summary – Public-Sector Cloud BI Analytics  
**AWS + Athena + Power BI | Reliability, Performance, FinOps**

This summary provides short, medium, and long-form descriptions of the project, designed for recruiters, hiring managers, portfolio sites, and interviews.


# 1. Short Summary (for LinkedIn, GitHub intro, recruiter review)

Designed and built a full **public-sector cloud BI analytics platform** using **AWS (S3, Glue, Athena)** and **Power BI**, focused on:
- **Digital Service Reliability & SLA performance**
- **FinOps — Budget Governance, Forecasting & Cloud Cost Optimization**
  
Delivered a curated star schema, Athena-based data lake, and executive dashboards that demonstrate end-to-end BI engineering capability in an AWS environment with real-world public-sector constraints.


# 2. Medium Summary (for GitHub pinned repo / portfolio description)

A full end-to-end AWS analytics solution simulating how government ministries track the performance and cost of cloud-hosted digital services.  
Built using **S3, Glue (manual metadata), Athena SQL, CTAS pipelines, and Power BI**, the project includes:

- **Hybrid Glue/Athena data ingestion** (crawler-free, IAM-restricted environment)  
- **Curated star schema** supporting reliability and FinOps use cases  
- **Derived KPIs** (stability score, SLA breaches, waste %, tagging compliance, variance, forecasts)  
- **Executive dashboards** for Reliability and FinOps governance  
- **Engineering dashboards** for SLA root-cause analysis  

The architecture and modeling reflect the operational patterns of AWS Public Sector customers across the Caribbean and LATAM.


# 3. Long Summary (for interviews, website, and detailed case studies)

This project simulates the analytics ecosystem used by public-sector ministries after migrating citizen-facing digital services (e-payments, licensing, tax filing) to AWS.

Due to restricted IAM permissions—common in government accounts—the solution uses a **hybrid metadata strategy**:
- Databases created manually in Glue  
- Raw tables defined manually in Athena  
- Curated tables generated via **CTAS** into Parquet  

A complete **star schema** was designed with dimensions for agencies, dates, regions, and services; and facts for usage, cost, performance, governance, and provider spend.

Two business narratives were delivered:

### 1. Digital Service Reliability  
- Stability scoring (0–100) combining latency, error rate, utilisation  
- SLA breach detection  
- Peak vs non-peak performance analysis  
- Pre vs post migration improvements  
- Risk ranking of agencies and services  

### 2. FinOps & Cloud Cost Governance  
- Budget vs Actual variance analysis  
- Multi-month cost forecasting  
- Waste estimation (idle resources)  
- Tagging compliance & untagged cost (governance risk)  
- Multi-cloud provider strategy (AWS vs Azure vs GCP)  

The final dashboards include both **executive summaries** (one-page views) and detailed engineering/financial analysis layers.

This project demonstrates real-world AWS BI capabilities:
- Data modeling  
- Cloud architecture  
- SQL transformation and CTAS optimization  
- FinOps analytics  
- Public-sector reporting standards  
- Executive storytelling  
