# GA4 Funnel & Channel Quality Analysis

End-to-end analytics project on Google's public GA4 e-commerce dataset (4.3M events, 270K users, Nov 2020 – Jan 2021). It answers the questions a growth / performance marketing team asks: which channels bring valuable users, where users drop off and who comes back.

**Stack:** BigQuery (SQL) · Python (pandas, statsmodels, scipy) · Tableau Public

## Approach

1. **Datamart in BigQuery:** staging → core (`dim_users`, `fct_sessions`, `fct_orders`) → marts, with data tests after every layer.
2. **Data quality first:** 11 issues found and documented before drawing conclusions ([docs/data_quality.md](docs/data_quality.md)).
3. **Statistics in Python:** hypothesis testing, power analysis and logistic regression ([notebooks/analysis.ipynb](notebooks/analysis.ipynb)).

## Key Findings

| Question | Finding |
|---|---|
| Data quality | Duplicate purchase events inflated average order value by **27%** (81.35 → 64.01 USD). |
| Where do users drop off? | **77%** of users leave without viewing a product; **41%** of checkout starters drop before entering payment info. Same pattern across channels and devices. |
| Which channel brings valuable users? | Organic Search brings **38%** of users but the lowest revenue per user ($1.14 vs $1.25 average). |
| Do new users come back? | Only **2.1%** return in their second week. Holiday cohorts were 33% larger but returned at less than half the rate. |
| Why did conversion drop? | Conversion fell **72%** from mid-December to early January while traffic fell only 25%. The break was at the product → checkout step. A revenue tracking break from Jan 26 was also detected. |
| Paid vs organic? | No difference (1.53% vs 1.53%, p = 0.97). Power analysis shows a 21% relative difference would have been detected. |
| What predicts a purchase? | 60% of new users who buy within 7 days do so in their first session. After removing this target leakage (AUC 0.94 → 0.87), product views and engagement predict later purchases, while channel does not. A simple rule (1+ min engagement or 4+ product views) targets **18%** of non-buyers and captures **78%** of later buyers. |

## Repository

```
sql/
├── 00_exploration/   first look at the raw data
├── 01_staging/       stg_events (+ checks)
├── 02_core/          dim_users, fct_sessions, fct_orders (+ checks)
└── 03_marts/         funnel, channel quality, cohort retention, daily KPIs, first session (+ checks)
notebooks/            hypothesis tests, logistic regression, retargeting audience
data/                 CSV exports used by the dashboard
docs/                 data quality notes
```

## How to Run

1. Create a BigQuery project and a dataset in the **US** region (the free BigQuery Sandbox is enough).
2. Run the SQL files in order: `01_staging` → `02_core` → `03_marts`, and the `*_checks.sql` files after each layer.
3. Set up Python and run the notebook (set `PROJECT_ID` to your project):

```bash
uv venv --python 3.12
uv pip install -r requirements.txt
```
