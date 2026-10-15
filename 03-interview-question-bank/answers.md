# SQL Interview Question Bank: verified results

Every solution was executed on SQL Server against `00_setup_practice_db.sql`. The first rows of each result are shown.

## Q01: Total sales per customer, including customers with no orders

```sql
SELECT c.customer_id, c.customer_name, COALESCE(SUM(oi.qty * oi.unit_price), 0) AS total_sales
FROM dbo.Customers c
LEFT JOIN dbo.Orders o ON o.customer_id = c.customer_id AND o.status <> 'Cancelled'
LEFT JOIN dbo.OrderItems oi ON oi.order_id = o.order_id
GROUP BY c.customer_id, c.customer_name
ORDER BY total_sales DESC;
```

|   customer_id | customer_name   |   total_sales |
|--------------:|:----------------|--------------:|
|            51 | Mona Alzahrani  |         48825 |
|            15 | Reem Alotaibi   |         44270 |
|            11 | Mona Alzahrani  |         42780 |
|            33 | Dana Alshammari |         41080 |
|             6 | Omar Alanazi    |         37745 |
|             4 | Saud Alghamdi   |         30450 |
|            21 | Huda Alzahrani  |         29420 |
|            46 | Omar Alanazi    |         29165 |

## Q02: Customers who never placed an order

```sql
SELECT c.customer_id, c.customer_name
FROM dbo.Customers c
WHERE NOT EXISTS (SELECT 1 FROM dbo.Orders o WHERE o.customer_id = c.customer_id);
```

|   customer_id | customer_name   |
|--------------:|:----------------|
|            56 | Turki Alanazi   |
|            57 | Rana Alqahtani  |
|            58 | Faisal Aldosari |
|            59 | Amal Almutairi  |
|            60 | Ahmed Alharbi   |

## Q03: Departments whose average salary is above the company average

```sql
SELECT d.dept_name, AVG(e.salary) AS avg_salary
FROM dbo.Employees e JOIN dbo.Departments d ON d.dept_id = e.dept_id
GROUP BY d.dept_name
HAVING AVG(e.salary) > (SELECT AVG(salary) FROM dbo.Employees)
ORDER BY avg_salary DESC;
```

| dept_name   |   avg_salary |
|:------------|-------------:|
| Executive   |        52000 |
| Finance     |        27654 |
| HR          |        25130 |
| IT          |        24644 |

## Q04: Orders by status with percent of total

```sql
SELECT status, COUNT(*) AS orders,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS pct_of_total
FROM dbo.Orders
GROUP BY status
ORDER BY orders DESC;
```

| status    |   orders |   pct_of_total |
|:----------|---------:|---------------:|
| Delivered |      244 |          46.92 |
| Shipped   |      100 |          19.23 |
| Cancelled |       91 |          17.5  |
| Returned  |       85 |          16.35 |

## Q05: Products that were never sold

```sql
SELECT p.product_id, p.product_name
FROM dbo.Products p
LEFT JOIN dbo.OrderItems oi ON oi.product_id = p.product_id
WHERE oi.product_id IS NULL;
```

|   product_id | product_name   |
|-------------:|:---------------|
|           24 | SQL Guide      |
|           25 | Atlas          |

## Q06: COUNT(*) vs COUNT(column): orders not yet shipped

```sql
SELECT COUNT(*) AS all_orders, COUNT(shipped_date) AS with_ship_date,
       COUNT(*) - COUNT(shipped_date) AS without_ship_date
FROM dbo.Orders;
```

|   all_orders |   with_ship_date |   without_ship_date |
|-------------:|-----------------:|--------------------:|
|          520 |              429 |                  91 |

## Q07: Duplicate e-mails

```sql
SELECT email, COUNT(*) AS occurrences
FROM dbo.Employees
GROUP BY email
HAVING COUNT(*) > 1;
```

| email                   |   occurrences |
|:------------------------|--------------:|
| ahmed.alharbi@corp.sa   |             2 |
| amal.alshammari@corp.sa |             2 |
| dana.alzahrani@corp.sa  |             2 |
| faisal.alshehri@corp.sa |             2 |
| lama.almutairi@corp.sa  |             2 |
| majed.alharbi@corp.sa   |             2 |
| reem.alotaibi@corp.sa   |             2 |
| turki.alshehri@corp.sa  |             2 |

## Q08: Hires per year and department (conditional aggregation)

```sql
SELECT YEAR(hire_date) AS hire_year,
       SUM(CASE WHEN dept_id = 2 THEN 1 ELSE 0 END) AS sales,
       SUM(CASE WHEN dept_id = 4 THEN 1 ELSE 0 END) AS it,
       SUM(CASE WHEN dept_id = 3 THEN 1 ELSE 0 END) AS finance,
       COUNT(*) AS all_departments
FROM dbo.Employees
GROUP BY YEAR(hire_date)
ORDER BY hire_year;
```

|   hire_year |   sales |   it |   finance |   all_departments |
|------------:|--------:|-----:|----------:|------------------:|
|        2015 |       0 |    0 |         0 |                 1 |
|        2016 |       0 |    1 |         0 |                 3 |
|        2017 |       0 |    0 |         0 |                 2 |
|        2018 |       1 |    0 |         1 |                 4 |
|        2019 |       0 |    0 |         1 |                 4 |
|        2020 |       1 |    0 |         0 |                 2 |
|        2021 |       1 |    1 |         0 |                 4 |
|        2022 |       0 |    1 |         0 |                 2 |

## Q09: Employees who earn more than their manager

```sql
SELECT e.full_name AS employee, e.salary, m.full_name AS manager, m.salary AS manager_salary
FROM dbo.Employees e
JOIN dbo.Employees m ON m.emp_id = e.manager_id
WHERE e.salary > m.salary;
```

| employee      |   salary | manager         |   manager_salary |
|:--------------|---------:|:----------------|-----------------:|
| Hind Alotaibi |    40000 | Noura Alzahrani |            36766 |

## Q10: Managers with at least 4 direct reports

```sql
SELECT m.full_name AS manager, COUNT(*) AS direct_reports
FROM dbo.Employees e
JOIN dbo.Employees m ON m.emp_id = e.manager_id
GROUP BY m.full_name
HAVING COUNT(*) >= 4;
```

| manager         |   direct_reports |
|:----------------|-----------------:|
| Ahmed Alharbi   |                7 |
| Faisal Alshehri |                5 |
| Huda Almutairi  |                5 |
| Noura Alzahrani |                4 |
| Saud Alanazi    |                5 |

## Q11: Employee, department and manager in one list (keep the CEO)

```sql
SELECT e.emp_id, e.full_name, d.dept_name, COALESCE(m.full_name, '(no manager)') AS manager
FROM dbo.Employees e
JOIN dbo.Departments d ON d.dept_id = e.dept_id
LEFT JOIN dbo.Employees m ON m.emp_id = e.manager_id
ORDER BY e.emp_id;
```

|   emp_id | full_name       | dept_name   | manager       |
|---------:|:----------------|:------------|:--------------|
|        1 | Ahmed Alharbi   | Executive   | (no manager)  |
|        2 | Omar Alghamdi   | Sales       | Ahmed Alharbi |
|        3 | Noura Alzahrani | Finance     | Ahmed Alharbi |
|        4 | Khalid Aldosari | IT          | Ahmed Alharbi |
|        5 | Reem Alotaibi   | HR          | Ahmed Alharbi |
|        6 | Faisal Alshehri | Operations  | Ahmed Alharbi |
|        7 | Huda Almutairi  | Marketing   | Ahmed Alharbi |
|        8 | Saud Alanazi    | Legal       | Ahmed Alharbi |

## Q12: Order value and number of items per order (top 10)

```sql
SELECT TOP 10 o.order_id, o.order_date, COUNT(*) AS lines, SUM(oi.qty * oi.unit_price) AS order_value
FROM dbo.Orders o JOIN dbo.OrderItems oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.order_date
ORDER BY order_value DESC;
```

|   order_id | order_date   |   lines |   order_value |
|-----------:|:-------------|--------:|--------------:|
|       1016 | 2024-03-20   |       3 |         16360 |
|       1311 | 2024-03-28   |       3 |         12540 |
|       1189 | 2025-09-13   |       3 |         11780 |
|       1241 | 2025-06-04   |       3 |         11460 |
|       1132 | 2024-09-17   |       3 |         11370 |
|       1361 | 2024-02-13   |       3 |         11010 |
|       1251 | 2024-12-01   |       2 |         11000 |
|       1114 | 2024-12-12   |       3 |         10860 |

## Q13: Customers who bought both a Laptop and Headphones

```sql
SELECT o.customer_id
FROM dbo.Orders o
JOIN dbo.OrderItems oi ON oi.order_id = o.order_id
JOIN dbo.Products p ON p.product_id = oi.product_id
WHERE p.product_name IN ('Laptop', 'Headphones')
GROUP BY o.customer_id
HAVING COUNT(DISTINCT p.product_name) = 2;
```

|   customer_id |
|--------------:|
|             2 |
|             4 |
|             6 |
|             8 |
|            13 |
|            19 |
|            21 |
|            23 |

## Q14: Customers who bought a Laptop but never Headphones

```sql
SELECT o.customer_id FROM dbo.Orders o JOIN dbo.OrderItems oi ON oi.order_id = o.order_id WHERE oi.product_id = 1
EXCEPT
SELECT o.customer_id FROM dbo.Orders o JOIN dbo.OrderItems oi ON oi.order_id = o.order_id WHERE oi.product_id = 3;
```

|   customer_id |
|--------------:|
|             3 |
|             5 |
|             9 |
|            11 |
|            15 |
|            40 |
|            43 |
|            51 |

## Q15: Second highest salary (ties and the no-result case)

```sql
SELECT MAX(salary) AS second_highest
FROM (SELECT salary, DENSE_RANK() OVER (ORDER BY salary DESC) AS rk FROM dbo.Employees) t
WHERE rk = 2;
```

|   second_highest |
|-----------------:|
|            40000 |

## Q16: Highest-paid employee(s) in each department

```sql
SELECT dept_id, full_name, salary
FROM (SELECT dept_id, full_name, salary, RANK() OVER (PARTITION BY dept_id ORDER BY salary DESC) AS rk
      FROM dbo.Employees) t
WHERE rk = 1
ORDER BY dept_id;
```

|   dept_id | full_name       |   salary |
|----------:|:----------------|---------:|
|         1 | Ahmed Alharbi   |    52000 |
|         2 | Omar Alghamdi   |    37338 |
|         3 | Hind Alotaibi   |    40000 |
|         4 | Khalid Aldosari |    36003 |
|         5 | Reem Alotaibi   |    29601 |
|         6 | Faisal Alshehri |    36951 |
|         7 | Huda Almutairi  |    35854 |
|         8 | Saud Alanazi    |    27428 |

## Q17: Top 2 products by revenue in each category

```sql
WITH rev AS (
    SELECT p.category, p.product_name, SUM(oi.qty * oi.unit_price) AS revenue,
           ROW_NUMBER() OVER (PARTITION BY p.category ORDER BY SUM(oi.qty * oi.unit_price) DESC) AS rn
    FROM dbo.OrderItems oi JOIN dbo.Products p ON p.product_id = oi.product_id
    GROUP BY p.category, p.product_name
)
SELECT category, product_name, revenue FROM rev WHERE rn <= 2 ORDER BY category, rn;
```

| category    | product_name   |   revenue |
|:------------|:---------------|----------:|
| Beauty      | Oud            |    108900 |
| Beauty      | Perfume        |     45600 |
| Books       | Cookbook       |     12600 |
| Books       | Novel          |      4740 |
| Electronics | Laptop         |    256000 |
| Electronics | Phone          |    223600 |
| Fashion     | Watch          |     81340 |
| Fashion     | Bag            |     58240 |

## Q18: Running total of monthly revenue in 2025

```sql
WITH m AS (
    SELECT DATEFROMPARTS(YEAR(o.order_date), MONTH(o.order_date), 1) AS month_start, SUM(oi.qty * oi.unit_price) AS revenue
    FROM dbo.Orders o JOIN dbo.OrderItems oi ON oi.order_id = o.order_id
    WHERE YEAR(o.order_date) = 2025 AND o.status <> 'Cancelled'
    GROUP BY DATEFROMPARTS(YEAR(o.order_date), MONTH(o.order_date), 1)
)
SELECT month_start, revenue, SUM(revenue) OVER (ORDER BY month_start ROWS UNBOUNDED PRECEDING) AS running_total
FROM m ORDER BY month_start;
```

| month_start   |   revenue |   running_total |
|:--------------|----------:|----------------:|
| 2025-01-01    |     14755 |           14755 |
| 2025-02-01    |     54290 |           69045 |
| 2025-03-01    |     49830 |          118875 |
| 2025-04-01    |     41385 |          160260 |
| 2025-05-01    |     36545 |          196805 |
| 2025-06-01    |     39170 |          235975 |
| 2025-07-01    |     39195 |          275170 |
| 2025-08-01    |     32760 |          307930 |

## Q19: 3-month moving average of revenue

```sql
WITH m AS (
    SELECT DATEFROMPARTS(YEAR(o.order_date), MONTH(o.order_date), 1) AS month_start, SUM(oi.qty * oi.unit_price) AS revenue
    FROM dbo.Orders o JOIN dbo.OrderItems oi ON oi.order_id = o.order_id
    WHERE o.status <> 'Cancelled'
    GROUP BY DATEFROMPARTS(YEAR(o.order_date), MONTH(o.order_date), 1)
)
SELECT month_start, revenue,
       AVG(revenue) OVER (ORDER BY month_start ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving_avg_3m
FROM m ORDER BY month_start;
```

| month_start   |   revenue |   moving_avg_3m |
|:--------------|----------:|----------------:|
| 2024-01-01    |     21350 |         21350   |
| 2024-02-01    |     41530 |         31440   |
| 2024-03-01    |     70650 |         44510   |
| 2024-04-01    |     34635 |         48938.3 |
| 2024-05-01    |     50615 |         51966.7 |
| 2024-06-01    |     26890 |         37380   |
| 2024-07-01    |     38145 |         38550   |
| 2024-08-01    |     43600 |         36211.7 |

## Q20: Month-over-month growth %

```sql
WITH m AS (
    SELECT DATEFROMPARTS(YEAR(o.order_date), MONTH(o.order_date), 1) AS month_start, SUM(oi.qty * oi.unit_price) AS revenue
    FROM dbo.Orders o JOIN dbo.OrderItems oi ON oi.order_id = o.order_id
    WHERE o.status <> 'Cancelled'
    GROUP BY DATEFROMPARTS(YEAR(o.order_date), MONTH(o.order_date), 1)
)
SELECT month_start, revenue, LAG(revenue) OVER (ORDER BY month_start) AS prev_month,
       CAST(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month_start))
            / NULLIF(LAG(revenue) OVER (ORDER BY month_start), 0) AS DECIMAL(8,2)) AS mom_pct
FROM m ORDER BY month_start;
```

| month_start   |   revenue |   prev_month |   mom_pct |
|:--------------|----------:|-------------:|----------:|
| 2024-01-01    |     21350 |              |           |
| 2024-02-01    |     41530 |        21350 |     94.52 |
| 2024-03-01    |     70650 |        41530 |     70.12 |
| 2024-04-01    |     34635 |        70650 |    -50.98 |
| 2024-05-01    |     50615 |        34635 |     46.14 |
| 2024-06-01    |     26890 |        50615 |    -46.87 |
| 2024-07-01    |     38145 |        26890 |     41.86 |
| 2024-08-01    |     43600 |        38145 |     14.3  |

## Q21: Year-over-year growth by month

```sql
WITH m AS (
    SELECT YEAR(o.order_date) AS yr, MONTH(o.order_date) AS mo, SUM(oi.qty * oi.unit_price) AS revenue
    FROM dbo.Orders o JOIN dbo.OrderItems oi ON oi.order_id = o.order_id
    WHERE o.status <> 'Cancelled'
    GROUP BY YEAR(o.order_date), MONTH(o.order_date)
)
SELECT cur.mo, prev.revenue AS revenue_2024, cur.revenue AS revenue_2025,
       CAST(100.0 * (cur.revenue - prev.revenue) / NULLIF(prev.revenue, 0) AS DECIMAL(8,2)) AS yoy_pct
FROM m cur JOIN m prev ON prev.mo = cur.mo AND prev.yr = cur.yr - 1
WHERE cur.yr = 2025 ORDER BY cur.mo;
```

|   mo |   revenue_2024 |   revenue_2025 |   yoy_pct |
|-----:|---------------:|---------------:|----------:|
|    1 |          21350 |          14755 |    -30.89 |
|    2 |          41530 |          54290 |     30.72 |
|    3 |          70650 |          49830 |    -29.47 |
|    4 |          34635 |          41385 |     19.49 |
|    5 |          50615 |          36545 |    -27.8  |
|    6 |          26890 |          39170 |     45.67 |
|    7 |          38145 |          39195 |      2.75 |
|    8 |          43600 |          32760 |    -24.86 |

## Q22: First and last order date of each customer

```sql
SELECT customer_id, MIN(order_date) AS first_order, MAX(order_date) AS last_order,
       DATEDIFF(DAY, MIN(order_date), MAX(order_date)) AS days_active, COUNT(*) AS orders
FROM dbo.Orders
GROUP BY customer_id
ORDER BY orders DESC;
```

|   customer_id | first_order   | last_order   |   days_active |   orders |
|--------------:|:--------------|:-------------|--------------:|---------:|
|             6 | 2024-03-27    | 2025-12-25   |           638 |       16 |
|            36 | 2024-05-20    | 2025-08-15   |           452 |       16 |
|            49 | 2024-01-07    | 2025-12-20   |           713 |       16 |
|            51 | 2024-03-09    | 2025-12-14   |           645 |       15 |
|            26 | 2024-06-04    | 2025-12-01   |           545 |       15 |
|            21 | 2024-01-16    | 2025-11-03   |           657 |       14 |
|            11 | 2024-04-30    | 2025-12-24   |           603 |       14 |
|            10 | 2024-02-26    | 2025-08-07   |           528 |       13 |

## Q23: Average days between consecutive orders per customer

```sql
WITH g AS (
    SELECT customer_id, DATEDIFF(DAY, LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date), order_date) AS gap_days
    FROM dbo.Orders
)
SELECT TOP 10 customer_id, AVG(1.0 * gap_days) AS avg_gap_days, COUNT(gap_days) AS gaps
FROM g WHERE gap_days IS NOT NULL
GROUP BY customer_id
ORDER BY avg_gap_days;
```

|   customer_id |   avg_gap_days |   gaps |
|--------------:|---------------:|-------:|
|            36 |        30.1333 |     15 |
|            26 |        38.9286 |     14 |
|            43 |        42.3    |     10 |
|             6 |        42.5333 |     15 |
|            10 |        44      |     12 |
|            51 |        46.0714 |     14 |
|            11 |        46.3846 |     13 |
|            49 |        47.5333 |     15 |

## Q24: Revenue share of each category

```sql
SELECT p.category, SUM(oi.qty * oi.unit_price) AS revenue,
       CAST(100.0 * SUM(oi.qty * oi.unit_price) / SUM(SUM(oi.qty * oi.unit_price)) OVER () AS DECIMAL(5,2)) AS share_pct
FROM dbo.OrderItems oi JOIN dbo.Products p ON p.product_id = oi.product_id
GROUP BY p.category ORDER BY revenue DESC;
```

| category    |   revenue |   share_pct |
|:------------|----------:|------------:|
| Electronics |    611540 |       48.02 |
| Beauty      |    244120 |       19.17 |
| Fashion     |    229410 |       18.01 |
| Home        |    168035 |       13.19 |
| Books       |     20445 |        1.61 |

## Q25: Salary quartiles

```sql
SELECT quartile, COUNT(*) AS employees, MIN(salary) AS min_salary, MAX(salary) AS max_salary
FROM (SELECT salary, NTILE(4) OVER (ORDER BY salary) AS quartile FROM dbo.Employees) t
GROUP BY quartile ORDER BY quartile;
```

|   quartile |   employees |   min_salary |   max_salary |
|-----------:|------------:|-------------:|-------------:|
|          1 |           9 |         9884 |        16173 |
|          2 |           9 |        18269 |        25645 |
|          3 |           9 |        25645 |        29601 |
|          4 |           8 |        29858 |        52000 |

## Q26: Median order value

```sql
WITH v AS (
    SELECT o.order_id, SUM(oi.qty * oi.unit_price) AS order_value
    FROM dbo.Orders o JOIN dbo.OrderItems oi ON oi.order_id = o.order_id GROUP BY o.order_id
)
SELECT DISTINCT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY order_value) OVER () AS median_value,
       AVG(order_value) OVER () AS mean_value
FROM v;
```

|   median_value |   mean_value |
|---------------:|-------------:|
|         1577.5 |      2449.13 |

## Q27: Users who logged in on 3+ consecutive days

```sql
WITH g AS (
    SELECT user_id, login_date,
           DATEADD(DAY, -ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY login_date), login_date) AS grp
    FROM dbo.Logins
)
SELECT DISTINCT user_id
FROM g
GROUP BY user_id, grp
HAVING COUNT(*) >= 3
ORDER BY user_id;
```

|   user_id |
|----------:|
|         1 |
|         2 |
|         3 |
|         4 |
|         5 |
|         6 |
|         7 |
|         8 |

## Q28: Longest login streak per user

```sql
WITH g AS (
    SELECT user_id, login_date, DATEADD(DAY, -ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY login_date), login_date) AS grp
    FROM dbo.Logins
), islands AS (
    SELECT user_id, MIN(login_date) AS streak_start, COUNT(*) AS streak_days,
           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY COUNT(*) DESC, MIN(login_date)) AS rn
    FROM g GROUP BY user_id, grp
)
SELECT TOP 10 user_id, streak_start, streak_days FROM islands WHERE rn = 1 ORDER BY streak_days DESC, user_id;
```

|   user_id | streak_start   |   streak_days |
|----------:|:---------------|--------------:|
|         1 | 2025-12-29     |             6 |
|         2 | 2025-11-09     |             6 |
|         4 | 2025-10-09     |             6 |
|         5 | 2025-10-06     |             6 |
|         7 | 2025-12-10     |             6 |
|         8 | 2025-10-10     |             6 |
|         9 | 2025-10-17     |             6 |
|        10 | 2025-10-03     |             6 |

## Q29: Monthly active users and month-to-month retention

```sql
WITH m AS (SELECT DISTINCT user_id, DATEFROMPARTS(YEAR(login_date), MONTH(login_date), 1) AS mo FROM dbo.Logins)
SELECT a.mo, COUNT(DISTINCT a.user_id) AS active_users, COUNT(DISTINCT b.user_id) AS retained_next_month,
       CAST(100.0 * COUNT(DISTINCT b.user_id) / COUNT(DISTINCT a.user_id) AS DECIMAL(5,1)) AS retention_pct
FROM m a LEFT JOIN m b ON b.user_id = a.user_id AND b.mo = DATEADD(MONTH, 1, a.mo)
GROUP BY a.mo ORDER BY a.mo;
```

| mo         |   active_users |   retained_next_month |   retention_pct |
|:-----------|---------------:|----------------------:|----------------:|
| 2025-10-01 |             40 |                    40 |           100   |
| 2025-11-01 |             40 |                    40 |           100   |
| 2025-12-01 |             40 |                     9 |            22.5 |
| 2026-01-01 |              9 |                     0 |             0   |

## Q30: New vs returning customers per month

```sql
WITH firsts AS (SELECT customer_id, MIN(order_date) AS first_order FROM dbo.Orders GROUP BY customer_id),
mo AS (SELECT DISTINCT o.customer_id, DATEFROMPARTS(YEAR(o.order_date), MONTH(o.order_date), 1) AS mo FROM dbo.Orders o)
SELECT mo.mo,
       SUM(CASE WHEN DATEFROMPARTS(YEAR(f.first_order), MONTH(f.first_order), 1) = mo.mo THEN 1 ELSE 0 END) AS new_customers,
       SUM(CASE WHEN DATEFROMPARTS(YEAR(f.first_order), MONTH(f.first_order), 1) < mo.mo THEN 1 ELSE 0 END) AS returning_customers
FROM mo JOIN firsts f ON f.customer_id = mo.customer_id
WHERE YEAR(mo.mo) = 2025
GROUP BY mo.mo ORDER BY mo.mo;
```

| mo         |   new_customers |   returning_customers |
|:-----------|----------------:|----------------------:|
| 2025-01-01 |               0 |                    12 |
| 2025-02-01 |               0 |                    16 |
| 2025-03-01 |               0 |                    17 |
| 2025-04-01 |               0 |                    12 |
| 2025-05-01 |               0 |                    16 |
| 2025-06-01 |               0 |                    14 |
| 2025-07-01 |               0 |                    21 |
| 2025-08-01 |               0 |                    20 |

## Q31: Cohort retention by quarter of first order

```sql
WITH f AS (SELECT customer_id, MIN(order_date) AS first_order FROM dbo.Orders GROUP BY customer_id),
a AS (
    SELECT o.customer_id, DATEPART(YEAR, f.first_order) * 10 + DATEPART(QUARTER, f.first_order) AS cohort,
           (YEAR(o.order_date) - YEAR(f.first_order)) * 4 + DATEPART(QUARTER, o.order_date) - DATEPART(QUARTER, f.first_order) AS q_offset
    FROM dbo.Orders o JOIN f ON f.customer_id = o.customer_id
)
SELECT cohort,
       COUNT(DISTINCT CASE WHEN q_offset = 0 THEN customer_id END) AS q0,
       COUNT(DISTINCT CASE WHEN q_offset = 1 THEN customer_id END) AS q1,
       COUNT(DISTINCT CASE WHEN q_offset = 2 THEN customer_id END) AS q2,
       COUNT(DISTINCT CASE WHEN q_offset = 3 THEN customer_id END) AS q3
FROM a GROUP BY cohort ORDER BY cohort;
```

|   cohort |   q0 |   q1 |   q2 |   q3 |
|---------:|-----:|-----:|-----:|-----:|
|    20241 |   38 |   27 |   29 |   31 |
|    20242 |   15 |   12 |   10 |    9 |
|    20243 |    2 |    1 |    1 |    2 |

## Q32: Daily revenue for December 2025 including days with no sales

```sql
WITH days AS (
    SELECT CAST('2025-12-01' AS DATE) AS d
    UNION ALL SELECT DATEADD(DAY, 1, d) FROM days WHERE d < '2025-12-31'
), s AS (
    SELECT o.order_date, SUM(oi.qty * oi.unit_price) AS revenue
    FROM dbo.Orders o JOIN dbo.OrderItems oi ON oi.order_id = o.order_id
    WHERE o.order_date BETWEEN '2025-12-01' AND '2025-12-31' AND o.status <> 'Cancelled'
    GROUP BY o.order_date
)
SELECT days.d, COALESCE(s.revenue, 0) AS revenue
FROM days LEFT JOIN s ON s.order_date = days.d
ORDER BY days.d
OPTION (MAXRECURSION 100);
```

| d          |   revenue |
|:-----------|----------:|
| 2025-12-01 |      5200 |
| 2025-12-02 |         0 |
| 2025-12-03 |      1140 |
| 2025-12-04 |       450 |
| 2025-12-05 |         0 |
| 2025-12-06 |         0 |
| 2025-12-07 |      3550 |
| 2025-12-08 |       480 |

## Q33: Customers whose second order came within 30 days of the first

```sql
WITH n AS (SELECT customer_id, order_date, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date, order_id) AS rn FROM dbo.Orders)
SELECT a.customer_id, a.order_date AS first_order, b.order_date AS second_order, DATEDIFF(DAY, a.order_date, b.order_date) AS days_between
FROM n a JOIN n b ON b.customer_id = a.customer_id AND a.rn = 1 AND b.rn = 2
WHERE DATEDIFF(DAY, a.order_date, b.order_date) <= 30
ORDER BY days_between;
```

|   customer_id | first_order   | second_order   |   days_between |
|--------------:|:--------------|:---------------|---------------:|
|            17 | 2024-02-18    | 2024-02-18     |              0 |
|            15 | 2024-06-03    | 2024-06-05     |              2 |
|            51 | 2024-03-09    | 2024-03-11     |              2 |
|             8 | 2024-02-17    | 2024-02-20     |              3 |
|            44 | 2024-01-31    | 2024-02-05     |              5 |
|            49 | 2024-01-07    | 2024-01-13     |              6 |
|             6 | 2024-03-27    | 2024-04-03     |              7 |
|            21 | 2024-01-16    | 2024-01-24     |              8 |

## Q34: Average delivery time by weekday ordered

```sql
SELECT DATENAME(WEEKDAY, order_date) AS weekday_name, COUNT(*) AS shipped_orders,
       AVG(1.0 * DATEDIFF(DAY, order_date, shipped_date)) AS avg_days_to_ship
FROM dbo.Orders
WHERE shipped_date IS NOT NULL
GROUP BY DATENAME(WEEKDAY, order_date)
ORDER BY avg_days_to_ship DESC;
```

| weekday_name   |   shipped_orders |   avg_days_to_ship |
|:---------------|-----------------:|-------------------:|
| Sunday         |               61 |            3.18033 |
| Friday         |               57 |            3.01754 |
| Wednesday      |               53 |            2.98113 |
| Thursday       |               67 |            2.91045 |
| Saturday       |               60 |            2.9     |
| Monday         |               73 |            2.78082 |
| Tuesday        |               58 |            2.58621 |

## Q35: Delete duplicate employees keeping the lowest id (safely)

```sql
BEGIN TRAN;
WITH d AS (SELECT emp_id, ROW_NUMBER() OVER (PARTITION BY email ORDER BY emp_id) AS rn FROM dbo.Employees)
DELETE FROM d WHERE rn > 1;
SELECT @@ROWCOUNT AS rows_deleted;
ROLLBACK;   -- use COMMIT in real life
```

|   rows_deleted |
|---------------:|
|              8 |

## Q36: Standardise messy city names

```sql
SELECT UPPER(LEFT(TRIM(city), 1)) + LOWER(SUBSTRING(TRIM(city), 2, 100)) AS city_clean, COUNT(*) AS customers
FROM dbo.Customers
GROUP BY UPPER(LEFT(TRIM(city), 1)) + LOWER(SUBSTRING(TRIM(city), 2, 100))
ORDER BY customers DESC;
```

| city_clean   |   customers |
|:-------------|------------:|
| Riyadh       |          24 |
| Dammam       |          16 |
| Jeddah       |          13 |
| Makkah       |           7 |

## Q37: Split full name into first and last name

```sql
SELECT TOP 5 full_name,
       LEFT(full_name, CHARINDEX(' ', full_name + ' ') - 1) AS first_name,
       LTRIM(SUBSTRING(full_name, CHARINDEX(' ', full_name + ' '), 100)) AS last_name
FROM dbo.Employees;
```

| full_name       | first_name   | last_name   |
|:----------------|:-------------|:------------|
| Ahmed Alharbi   | Ahmed        | Alharbi     |
| Omar Alghamdi   | Omar         | Alghamdi    |
| Noura Alzahrani | Noura        | Alzahrani   |
| Khalid Aldosari | Khalid       | Aldosari    |
| Reem Alotaibi   | Reem         | Alotaibi    |

## Q38: Cancellation rate per customer without divide-by-zero errors

```sql
SELECT TOP 10 customer_id,
       SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled, COUNT(*) AS orders,
       CAST(100.0 * SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) AS DECIMAL(5,1)) AS cancel_pct
FROM dbo.Orders GROUP BY customer_id ORDER BY cancel_pct DESC, orders DESC;
```

|   customer_id |   cancelled |   orders |   cancel_pct |
|--------------:|------------:|---------:|-------------:|
|            40 |           2 |        3 |         66.7 |
|             8 |           5 |       10 |         50   |
|            14 |           4 |       11 |         36.4 |
|            26 |           5 |       15 |         33.3 |
|            23 |           3 |        9 |         33.3 |
|            34 |           2 |        6 |         33.3 |
|            41 |           4 |       13 |         30.8 |
|            11 |           4 |       14 |         28.6 |

## Q39: Upsert a customer summary table with MERGE

```sql
BEGIN TRAN;
CREATE TABLE #summary (customer_id INT PRIMARY KEY, orders INT);
INSERT #summary VALUES (1, 0), (2, 0);
MERGE #summary AS t
USING (SELECT customer_id, COUNT(*) AS orders FROM dbo.Orders GROUP BY customer_id) AS s
ON t.customer_id = s.customer_id
WHEN MATCHED THEN UPDATE SET t.orders = s.orders
WHEN NOT MATCHED THEN INSERT (customer_id, orders) VALUES (s.customer_id, s.orders);
SELECT COUNT(*) AS rows_in_summary, SUM(orders) AS total_orders FROM #summary;
ROLLBACK;
```

|   rows_in_summary |   total_orders |
|------------------:|---------------:|
|                55 |            520 |

## Q40: Revenue by category and quarter (PIVOT)

```sql
SELECT category, [1] AS Q1, [2] AS Q2, [3] AS Q3, [4] AS Q4
FROM (
    SELECT p.category, DATEPART(QUARTER, o.order_date) AS qtr, oi.qty * oi.unit_price AS revenue
    FROM dbo.Orders o JOIN dbo.OrderItems oi ON oi.order_id = o.order_id JOIN dbo.Products p ON p.product_id = oi.product_id
    WHERE YEAR(o.order_date) = 2025
) s
PIVOT (SUM(revenue) FOR qtr IN ([1], [2], [3], [4])) pv
ORDER BY category;
```

| category    |    Q1 |    Q2 |    Q3 |    Q4 |
|:------------|------:|------:|------:|------:|
| Beauty      | 24500 | 27120 | 34400 | 15090 |
| Books       |  2970 |  2250 |  1845 |  1890 |
| Electronics | 65650 | 76700 | 38800 | 89280 |
| Fashion     | 15870 | 21630 | 52040 | 32880 |
| Home        | 22180 | 13610 | 34475 | 13390 |

## Q41: Unpivot quarterly targets (wide to long)

```sql
SELECT t.dept_id, v.quarter_name, v.target
FROM dbo.Targets t
CROSS APPLY (VALUES ('Q1', t.Q1), ('Q2', t.Q2), ('Q3', t.Q3), ('Q4', t.Q4)) AS v (quarter_name, target)
ORDER BY t.dept_id, v.quarter_name;
```

|   dept_id | quarter_name   |   target |
|----------:|:---------------|---------:|
|         1 | Q1             |   175000 |
|         1 | Q2             |   124000 |
|         1 | Q3             |   140000 |
|         1 | Q4             |    86000 |
|         2 | Q1             |   189000 |
|         2 | Q2             |    82000 |
|         2 | Q3             |    84000 |
|         2 | Q4             |    85000 |

## Q42: Org chart: level and reporting path (recursive CTE)

```sql
WITH org AS (
    SELECT emp_id, full_name, manager_id, 0 AS lvl, CAST(full_name AS NVARCHAR(400)) AS path
    FROM dbo.Employees WHERE manager_id IS NULL
    UNION ALL
    SELECT e.emp_id, e.full_name, e.manager_id, o.lvl + 1, CAST(o.path + N' > ' + e.full_name AS NVARCHAR(400))
    FROM dbo.Employees e JOIN org o ON e.manager_id = o.emp_id
)
SELECT TOP 12 emp_id, lvl, path FROM org ORDER BY path;
```

|   emp_id |   lvl | path                                               |
|---------:|------:|:---------------------------------------------------|
|        1 |     0 | Ahmed Alharbi                                      |
|        6 |     1 | Ahmed Alharbi > Faisal Alshehri                    |
|       20 |     2 | Ahmed Alharbi > Faisal Alshehri > Ahmed Alharbi    |
|       34 |     2 | Ahmed Alharbi > Faisal Alshehri > Faisal Alshehri  |
|       23 |     2 | Ahmed Alharbi > Faisal Alshehri > Noura Alshammari |
|       22 |     2 | Ahmed Alharbi > Faisal Alshehri > Omar Alshehri    |
|       21 |     2 | Ahmed Alharbi > Faisal Alshehri > Sara Alzahrani   |
|        7 |     1 | Ahmed Alharbi > Huda Almutairi                     |

## Q43: Pareto: products that make 80% of revenue

```sql
WITH r AS (
    SELECT p.product_name, SUM(oi.qty * oi.unit_price) AS revenue FROM dbo.OrderItems oi
    JOIN dbo.Products p ON p.product_id = oi.product_id GROUP BY p.product_name
), c AS (
    SELECT product_name, revenue,
           SUM(revenue) OVER (ORDER BY revenue DESC ROWS UNBOUNDED PRECEDING) / SUM(revenue) OVER () AS cum_share
    FROM r
)
SELECT product_name, revenue, CAST(cum_share AS DECIMAL(5,3)) AS cum_share
FROM c WHERE cum_share - revenue / (SELECT SUM(revenue) FROM r) < 0.8
ORDER BY revenue DESC;
```

| product_name   |   revenue |   cum_share |
|:---------------|----------:|------------:|
| Laptop         |    256000 |       0.201 |
| Phone          |    223600 |       0.377 |
| Oud            |    108900 |       0.462 |
| Watch          |     81340 |       0.526 |
| Monitor        |     80100 |       0.589 |
| Vacuum         |     64500 |       0.64  |
| Bag            |     58240 |       0.685 |
| Perfume        |     45600 |       0.721 |

## Q44: Customers whose spend grew 3 months in a row

```sql
WITH m AS (
    SELECT o.customer_id, DATEFROMPARTS(YEAR(o.order_date), MONTH(o.order_date), 1) AS mo, SUM(oi.qty * oi.unit_price) AS spend
    FROM dbo.Orders o JOIN dbo.OrderItems oi ON oi.order_id = o.order_id
    GROUP BY o.customer_id, DATEFROMPARTS(YEAR(o.order_date), MONTH(o.order_date), 1)
), l AS (
    SELECT *, LAG(spend, 1) OVER (PARTITION BY customer_id ORDER BY mo) AS s1, LAG(spend, 2) OVER (PARTITION BY customer_id ORDER BY mo) AS s2
    FROM m
)
SELECT DISTINCT customer_id FROM l WHERE spend > s1 AND s1 > s2 ORDER BY customer_id;
```

|   customer_id |
|--------------:|
|             1 |
|             3 |
|             4 |
|             6 |
|             7 |
|             9 |
|            11 |
|            12 |

## Q45: Department with the highest salary cost (keep ties)

```sql
SELECT TOP 1 WITH TIES d.dept_name, SUM(e.salary) AS salary_cost, COUNT(*) AS headcount
FROM dbo.Employees e JOIN dbo.Departments d ON d.dept_id = e.dept_id
GROUP BY d.dept_name
ORDER BY SUM(e.salary) DESC;
```

| dept_name   |   salary_cost |   headcount |
|:------------|--------------:|------------:|
| Marketing   |        142461 |           6 |

## Q46: Unusually large orders per customer (above mean + 2 standard deviations)

```sql
WITH v AS (
    SELECT o.customer_id, o.order_id, SUM(oi.qty * oi.unit_price) AS order_value
    FROM dbo.Orders o JOIN dbo.OrderItems oi ON oi.order_id = o.order_id GROUP BY o.customer_id, o.order_id
), s AS (
    SELECT *, AVG(order_value) OVER (PARTITION BY customer_id) AS avg_v,
           STDEV(order_value) OVER (PARTITION BY customer_id) AS sd_v, COUNT(*) OVER (PARTITION BY customer_id) AS n
    FROM v
)
SELECT customer_id, order_id, order_value, CAST(avg_v AS DECIMAL(10,1)) AS customer_avg
FROM s WHERE n >= 5 AND order_value > avg_v + 2 * sd_v
ORDER BY order_value DESC;
```

|   customer_id |   order_id |   order_value |   customer_avg |
|--------------:|-----------:|--------------:|---------------:|
|             6 |       1189 |         11780 |         2646.9 |
|            25 |       1241 |         11460 |         3236.7 |
|             2 |       1251 |         11000 |         2628   |
|            11 |       1400 |         10760 |         3511.8 |
|            23 |       1209 |         10660 |         3111.1 |
|            52 |       1234 |         10320 |         2620.5 |
|            51 |       1259 |         10220 |         3451   |
|            41 |       1499 |         10200 |         2400.4 |

## Q47: Query execution order: why can't WHERE use a SELECT alias?

```sql
SELECT full_name, a.annual
FROM dbo.Employees
CROSS APPLY (SELECT salary * 12 AS annual) a
WHERE a.annual > 300000
ORDER BY a.annual DESC;
```

| full_name       |   annual |
|:----------------|---------:|
| Ahmed Alharbi   |   624000 |
| Hind Alotaibi   |   480000 |
| Omar Alghamdi   |   448056 |
| Faisal Alshehri |   443412 |
| Noura Alzahrani |   441192 |
| Khalid Aldosari |   432036 |
| Huda Almutairi  |   430248 |
| Omar Alshehri   |   358296 |

## Q48: Index thinking: rewrite a non-sargable filter

```sql
SELECT COUNT(*) AS orders_2025
FROM dbo.Orders
WHERE order_date >= '2025-01-01' AND order_date < '2026-01-01';
```

|   orders_2025 |
|--------------:|
|           249 |
