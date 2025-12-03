# public-sector-cloud-BI-analytics
Showing a unified view of services after migration to the cloud

1. Project Title: Public Sector Cloud BI Analytics - Reliability, Performance & Cost Governance

2. Summary
    This Business Intelligence (BI) solution is designed to empower ministries and public-sector agencies by ensuring both the reliability and performance of their cloud services while simultaneously maintaining rigorous budget control and financial oversight. By integrating AWS-style telemetry data with FinOps cost data, the solution delivers actionable insights into service uptime, system performance, and operational expenditures. It enables agencies to monitor service reliability in real time, forecast future costs, and enforce governance practices to align with budget constraints. This dual-purpose approach supports both operational efficiency and financial accountability in the public sector's cloud environments.

3. Business Narratives
   a. Narrative 1 - Digital Service Reliability & Performance
                    As public sector agencies migrate to the cloud, maintaining digital service reliability and performance becomes critical. Often, cloud-based systems face challenges such as service disruptions or inconsistent performance. This BI solution addresses these issues by leveraging real-time telemetry data to monitor system uptime and performance, ensuring that any anomalies are quickly detected and resolved. By providing actionable insights, it helps agencies maintain the reliability needed for critical public services.

   b. Narrative 2 - Budget Governance & Forecasting
                    Cloud cost management is a significant challenge for public-sector agencies, with cost variability and waste often resulting from ineffective resource management and poor tagging practices. This BI solution integrates FinOps data to enable precise cost forecasting, enforce tagging governance, and identify inefficiencies. This approach helps agencies minimize waste, stay within budget, and ensure financial transparency while forecasting future expenses with greater accuracy.

4. Architecture Overview

5. Data Model / Star Schema
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

6. SQL Models
    RAW Layer
    This layer stores original, unaltered copies of the datasets simulated for this project in the S3 bucket. They are then registered in the Glue Data Catalog and queried in Athena but no transformations are applied to the originals.
    
    Curated Layer
    This layer cleans raw datasets into analysis-ready tables. It involves normalization, filtering, deriving of metrics and identification of keys for joins

    GOLD layers
    This layer contains business centered fact tables that support the BI story/ All key metrics and flags are calcualted and ready for visualization.

7. Python Notebooks
    *explain what each note book does e.g. cleaning, feature engineering and forecasting*

8. Dashboards
    Below are screenshots for each page of the PowerBI dashboard

    - Reliability Overview

    - SLA Performance

    - Peak vs Non-Peak

    - Budget Oversight

    - Forecasting

    - Governance & Waste

9. Key Insights
    Find 4 - 6 insights executives would take interest in
    e.g. Migration improved stability by 28% across critical services.”

        “Two agencies consumed 60% of the cloud budget due to storage-heavy workloads.”

        “Forecast indicates a 12% budget overrun by Q4 without efficiency improvements.”

        “Untagged cost accounted for 18% of spend, violating tagging policy guidelines.”

        “Idle resources represent $180K/year in avoidable waste.”

10. Recommendations
    High-level governance and optimisation guidance:

    - Improve tagging policies

    - Implement quarterly forecasting cycles

    - Rightsize idle or under-utilised workloads

    - Introduce cost anomaly alerts

    - Expand PaaS usage to reduce IaaS-heavy costs

11. How to Run this Project
    1. Clone Repo
    2. Upload raw files into S3
    3. Run Athena SQL scripts
    4. Execute Python notebooks
    5. Open PowerB Dashboard

12. Skills Demonstrated & Learned
    a. BI Engineering
    b. Data Modeling (Star Schema)
    c. AWS (S3, Glue, Athena)
    d. SQL (CTAS modeling)
    e. Python (pandas, forecasting)
    f. Power BI
    g. FinOps Governance
    h. Public-Sector Analytics

13. About the Author
    Write a short paragraph about myself using these egs. Public-sector BI & systems analyst, AWS-focused BI transition and digital government and cloud analytics