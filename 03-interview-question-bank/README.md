# SQL Interview Question Bank (SQL Server)

48 data-analyst interview questions with tested T-SQL solutions on a small, deterministic practice database.

| File | Content |
|---|---|
| `00_setup_practice_db.sql` | creates `InterviewPractice` (employees, departments, customers, products, orders, logins, targets) with deliberate traps: NULLs, ties, duplicates, messy text, missing days |
| `questions.sql` | questions only, for practice |
| `solutions.sql` | solutions |
| [`answers.md`](answers.md) | every solution with its actual output (first rows) |

## Topics
Joins and anti-joins · aggregation and HAVING · self-joins · `ROW_NUMBER` / `RANK` / `DENSE_RANK` / `NTILE` · running totals and moving averages · `LAG` (MoM, YoY, gaps between events) · gaps & islands (consecutive days, longest streak) · MAU retention and cohorts · recursive CTEs (date spines, org chart) · `PIVOT` / `CROSS APPLY` unpivot · Pareto · de-duplication with `DELETE` from a CTE · `MERGE` upsert · `NULLIF` safe division · logical query order · SARGable filters.

```bash
sqlcmd -S "(localdb)\MSSQLLocalDB" -E -i 00_setup_practice_db.sql
```
