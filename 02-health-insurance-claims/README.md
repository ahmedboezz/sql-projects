# Health-Insurance Claims Analytics (SQL Server)

End-to-end SQL project for a Saudi health insurer / TPA: staging → typed model with constraints → data-quality checks → 18 analysis queries → a reusable stored procedure.

> **Note:** simulated data for a realistic business scenario (portfolio case study). Provider and employer names are fictional.

## Data model
`core.Policies` (180 employer groups, CCHI-style classes VIP/A/B/C) → `core.Members` (42,000) → `core.Claims` (342,057) ← `core.Providers` (300) and `core.Diagnoses` (ICD-10).
Views: `vw_ClaimsClean` (de-duplicated), `vw_ClaimFacts` (wide BI view), `vw_MemberMonths` (recursive month spine).

## Run it
```bash
pip install pandas pyodbc tabulate
python run_project.py                 # (localdb)\MSSQLLocalDB by default
python run_project.py .\SQLEXPRESS    # or any SQL Server instance
```
Results are saved to `results/` (one CSV per query + [`all_results.md`](results/all_results.md)).

## SQL techniques shown
CTEs, window functions (`ROW_NUMBER`, `DENSE_RANK`, `LAG`, running `SUM`, `PERCENT_RANK`, `STDEV OVER`), `PERCENTILE_CONT`, `PIVOT`, recursive CTE, `EXISTS / NOT EXISTS`, dynamic SQL with `BULK INSERT`, `TRY_CONVERT` staging pattern, `CHECK` / `FOREIGN KEY` constraints, covering indexes, views, stored procedure with parameters.

## Key findings
| # | Finding |
|---|---|
| Duplicates | **1,800 re-submitted duplicate claims** (SAR 2.06M approved at risk) detected with `ROW_NUMBER()` |
| Loss ratio | Class **C 103.6%** (loss-making) vs VIP 85.8%, so class C needs re-pricing at renewal |
| Rule change | Hospital PRV0007 rejection rate jumped **4.9% → 31.0%** after pre-authorisation was enforced in June |
| Turnaround | Hospitals: median 26 days, P90 53 days, **40% breach the 30-day SLA** (vs about 18% elsewhere) |
| Concentration | Top 5% of members = **36% of cost**; chronic members cost **2.2x** per member |
| Outliers | 3 providers bill **7-8 standard deviations** above peers, with 33% partial approvals (possible up-coding) |
| Seasonality | Respiratory claims rise ~30% in Nov-Dec |

---
© 2026 Ahmed Abdulsalam. All rights reserved. See [LICENSE](../LICENSE).
