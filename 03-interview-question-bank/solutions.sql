/* SQL Interview Question Bank - solutions (SQL Server) */
USE InterviewPractice;
GO

-- Q01: Total sales per customer, including customers with no orders
SELECT c.customer_id, c.customer_name, COALESCE(SUM(oi.qty * oi.unit_price), 0) AS total_sales
FROM dbo.Customers c
LEFT JOIN dbo.Orders o ON o.customer_id = c.customer_id AND o.status <> 'Cancelled'
LEFT JOIN dbo.OrderItems oi ON oi.order_id = o.order_id
GROUP BY c.customer_id, c.customer_name
ORDER BY total_sales DESC;
GO

-- Q02: Customers who never placed an order
SELECT c.customer_id, c.customer_name
FROM dbo.Customers c
WHERE NOT EXISTS (SELECT 1 FROM dbo.Orders o WHERE o.customer_id = c.customer_id);
GO

-- Q03: Departments whose average salary is above the company average
SELECT d.dept_name, AVG(e.salary) AS avg_salary
FROM dbo.Employees e JOIN dbo.Departments d ON d.dept_id = e.dept_id
GROUP BY d.dept_name
HAVING AVG(e.salary) > (SELECT AVG(salary) FROM dbo.Employees)
ORDER BY avg_salary DESC;
GO

-- Q04: Orders by status with percent of total
SELECT status, COUNT(*) AS orders,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS pct_of_total
FROM dbo.Orders
GROUP BY status
ORDER BY orders DESC;
GO

-- Q05: Products that were never sold
SELECT p.product_id, p.product_name
FROM dbo.Products p
LEFT JOIN dbo.OrderItems oi ON oi.product_id = p.product_id
WHERE oi.product_id IS NULL;
GO

-- Q06: COUNT(*) vs COUNT(column): orders not yet shipped
SELECT COUNT(*) AS all_orders, COUNT(shipped_date) AS with_ship_date,
       COUNT(*) - COUNT(shipped_date) AS without_ship_date
FROM dbo.Orders;
GO

-- Q07: Duplicate e-mails
SELECT email, COUNT(*) AS occurrences
FROM dbo.Employees
GROUP BY email
HAVING COUNT(*) > 1;
GO

-- Q08: Hires per year and department (conditional aggregation)
SELECT YEAR(hire_date) AS hire_year,
       SUM(CASE WHEN dept_id = 2 THEN 1 ELSE 0 END) AS sales,
       SUM(CASE WHEN dept_id = 4 THEN 1 ELSE 0 END) AS it,
       SUM(CASE WHEN dept_id = 3 THEN 1 ELSE 0 END) AS finance,
       COUNT(*) AS all_departments
FROM dbo.Employees
GROUP BY YEAR(hire_date)
ORDER BY hire_year;
GO

-- Q09: Employees who earn more than their manager
SELECT e.full_name AS employee, e.salary, m.full_name AS manager, m.salary AS manager_salary
FROM dbo.Employees e
JOIN dbo.Employees m ON m.emp_id = e.manager_id
WHERE e.salary > m.salary;
GO

-- Q10: Managers with at least 4 direct reports
SELECT m.full_name AS manager, COUNT(*) AS direct_reports
FROM dbo.Employees e
JOIN dbo.Employees m ON m.emp_id = e.manager_id
GROUP BY m.full_name
HAVING COUNT(*) >= 4;
GO

-- Q11: Employee, department and manager in one list (keep the CEO)
SELECT e.emp_id, e.full_name, d.dept_name, COALESCE(m.full_name, '(no manager)') AS manager
FROM dbo.Employees e
JOIN dbo.Departments d ON d.dept_id = e.dept_id
LEFT JOIN dbo.Employees m ON m.emp_id = e.manager_id
ORDER BY e.emp_id;
GO

-- Q12: Order value and number of items per order (top 10)
SELECT TOP 10 o.order_id, o.order_date, COUNT(*) AS lines, SUM(oi.qty * oi.unit_price) AS order_value
FROM dbo.Orders o JOIN dbo.OrderItems oi ON oi.order_id = o.order_id
GROUP BY o.order_id, o.order_date
ORDER BY order_value DESC;
GO

-- Q13: Customers who bought both a Laptop and Headphones
SELECT o.customer_id
FROM dbo.Orders o
JOIN dbo.OrderItems oi ON oi.order_id = o.order_id
JOIN dbo.Products p ON p.product_id = oi.product_id
WHERE p.product_name IN ('Laptop', 'Headphones')
GROUP BY o.customer_id
HAVING COUNT(DISTINCT p.product_name) = 2;
GO

-- Q14: Customers who bought a Laptop but never Headphones
SELECT o.customer_id FROM dbo.Orders o JOIN dbo.OrderItems oi ON oi.order_id = o.order_id WHERE oi.product_id = 1
EXCEPT
SELECT o.customer_id FROM dbo.Orders o JOIN dbo.OrderItems oi ON oi.order_id = o.order_id WHERE oi.product_id = 3;
GO

-- Q15: Second highest salary (ties and the no-result case)
SELECT MAX(salary) AS second_highest
FROM (SELECT salary, DENSE_RANK() OVER (ORDER BY salary DESC) AS rk FROM dbo.Employees) t
WHERE rk = 2;
GO

-- Q16: Highest-paid employee(s) in each department
SELECT dept_id, full_name, salary
FROM (SELECT dept_id, full_name, salary, RANK() OVER (PARTITION BY dept_id ORDER BY salary DESC) AS rk
      FROM dbo.Employees) t
WHERE rk = 1
ORDER BY dept_id;
GO

-- Q17: Top 2 products by revenue in each category
WITH rev AS (
    SELECT p.category, p.product_name, SUM(oi.qty * oi.unit_price) AS revenue,
           ROW_NUMBER() OVER (PARTITION BY p.category ORDER BY SUM(oi.qty * oi.unit_price) DESC) AS rn
    FROM dbo.OrderItems oi JOIN dbo.Products p ON p.product_id = oi.product_id
    GROUP BY p.category, p.product_name
)
SELECT category, product_name, revenue FROM rev WHERE rn <= 2 ORDER BY category, rn;
GO

-- Q18: Running total of monthly revenue in 2025
WITH m AS (
    SELECT DATEFROMPARTS(YEAR(o.order_date), MONTH(o.order_date), 1) AS month_start, SUM(oi.qty * oi.unit_price) AS revenue
    FROM dbo.Orders o JOIN dbo.OrderItems oi ON oi.order_id = o.order_id
    WHERE YEAR(o.order_date) = 2025 AND o.status <> 'Cancelled'
    GROUP BY DATEFROMPARTS(YEAR(o.order_date), MONTH(o.order_date), 1)
)
SELECT month_start, revenue, SUM(revenue) OVER (ORDER BY month_start ROWS UNBOUNDED PRECEDING) AS running_total
FROM m ORDER BY month_start;
GO

-- Q19: 3-month moving average of revenue
WITH m AS (
    SELECT DATEFROMPARTS(YEAR(o.order_date), MONTH(o.order_date), 1) AS month_start, SUM(oi.qty * oi.unit_price) AS revenue
    FROM dbo.Orders o JOIN dbo.OrderItems oi ON oi.order_id = o.order_id
    WHERE o.status <> 'Cancelled'
    GROUP BY DATEFROMPARTS(YEAR(o.order_date), MONTH(o.order_date), 1)
)
SELECT month_start, revenue,
       AVG(revenue) OVER (ORDER BY month_start ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS moving_avg_3m
FROM m ORDER BY month_start;
GO

-- Q20: Month-over-month growth %
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
GO

-- Q21: Year-over-year growth by month
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
GO

-- Q22: First and last order date of each customer
SELECT customer_id, MIN(order_date) AS first_order, MAX(order_date) AS last_order,
       DATEDIFF(DAY, MIN(order_date), MAX(order_date)) AS days_active, COUNT(*) AS orders
FROM dbo.Orders
GROUP BY customer_id
ORDER BY orders DESC;
GO

-- Q23: Average days between consecutive orders per customer
WITH g AS (
    SELECT customer_id, DATEDIFF(DAY, LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date), order_date) AS gap_days
    FROM dbo.Orders
)
SELECT TOP 10 customer_id, AVG(1.0 * gap_days) AS avg_gap_days, COUNT(gap_days) AS gaps
FROM g WHERE gap_days IS NOT NULL
GROUP BY customer_id
ORDER BY avg_gap_days;
GO

-- Q24: Revenue share of each category
SELECT p.category, SUM(oi.qty * oi.unit_price) AS revenue,
       CAST(100.0 * SUM(oi.qty * oi.unit_price) / SUM(SUM(oi.qty * oi.unit_price)) OVER () AS DECIMAL(5,2)) AS share_pct
FROM dbo.OrderItems oi JOIN dbo.Products p ON p.product_id = oi.product_id
GROUP BY p.category ORDER BY revenue DESC;
GO

-- Q25: Salary quartiles
SELECT quartile, COUNT(*) AS employees, MIN(salary) AS min_salary, MAX(salary) AS max_salary
FROM (SELECT salary, NTILE(4) OVER (ORDER BY salary) AS quartile FROM dbo.Employees) t
GROUP BY quartile ORDER BY quartile;
GO

-- Q26: Median order value
WITH v AS (
    SELECT o.order_id, SUM(oi.qty * oi.unit_price) AS order_value
    FROM dbo.Orders o JOIN dbo.OrderItems oi ON oi.order_id = o.order_id GROUP BY o.order_id
)
SELECT DISTINCT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY order_value) OVER () AS median_value,
       AVG(order_value) OVER () AS mean_value
FROM v;
GO

-- Q27: Users who logged in on 3+ consecutive days
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
GO

-- Q28: Longest login streak per user
WITH g AS (
    SELECT user_id, login_date, DATEADD(DAY, -ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY login_date), login_date) AS grp
    FROM dbo.Logins
), islands AS (
    SELECT user_id, MIN(login_date) AS streak_start, COUNT(*) AS streak_days,
           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY COUNT(*) DESC, MIN(login_date)) AS rn
    FROM g GROUP BY user_id, grp
)
SELECT TOP 10 user_id, streak_start, streak_days FROM islands WHERE rn = 1 ORDER BY streak_days DESC, user_id;
GO

-- Q29: Monthly active users and month-to-month retention
WITH m AS (SELECT DISTINCT user_id, DATEFROMPARTS(YEAR(login_date), MONTH(login_date), 1) AS mo FROM dbo.Logins)
SELECT a.mo, COUNT(DISTINCT a.user_id) AS active_users, COUNT(DISTINCT b.user_id) AS retained_next_month,
       CAST(100.0 * COUNT(DISTINCT b.user_id) / COUNT(DISTINCT a.user_id) AS DECIMAL(5,1)) AS retention_pct
FROM m a LEFT JOIN m b ON b.user_id = a.user_id AND b.mo = DATEADD(MONTH, 1, a.mo)
GROUP BY a.mo ORDER BY a.mo;
GO

-- Q30: New vs returning customers per month
WITH firsts AS (SELECT customer_id, MIN(order_date) AS first_order FROM dbo.Orders GROUP BY customer_id),
mo AS (SELECT DISTINCT o.customer_id, DATEFROMPARTS(YEAR(o.order_date), MONTH(o.order_date), 1) AS mo FROM dbo.Orders o)
SELECT mo.mo,
       SUM(CASE WHEN DATEFROMPARTS(YEAR(f.first_order), MONTH(f.first_order), 1) = mo.mo THEN 1 ELSE 0 END) AS new_customers,
       SUM(CASE WHEN DATEFROMPARTS(YEAR(f.first_order), MONTH(f.first_order), 1) < mo.mo THEN 1 ELSE 0 END) AS returning_customers
FROM mo JOIN firsts f ON f.customer_id = mo.customer_id
WHERE YEAR(mo.mo) = 2025
GROUP BY mo.mo ORDER BY mo.mo;
GO

-- Q31: Cohort retention by quarter of first order
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
GO

-- Q32: Daily revenue for December 2025 including days with no sales
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
GO

-- Q33: Customers whose second order came within 30 days of the first
WITH n AS (SELECT customer_id, order_date, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date, order_id) AS rn FROM dbo.Orders)
SELECT a.customer_id, a.order_date AS first_order, b.order_date AS second_order, DATEDIFF(DAY, a.order_date, b.order_date) AS days_between
FROM n a JOIN n b ON b.customer_id = a.customer_id AND a.rn = 1 AND b.rn = 2
WHERE DATEDIFF(DAY, a.order_date, b.order_date) <= 30
ORDER BY days_between;
GO

-- Q34: Average delivery time by weekday ordered
SELECT DATENAME(WEEKDAY, order_date) AS weekday_name, COUNT(*) AS shipped_orders,
       AVG(1.0 * DATEDIFF(DAY, order_date, shipped_date)) AS avg_days_to_ship
FROM dbo.Orders
WHERE shipped_date IS NOT NULL
GROUP BY DATENAME(WEEKDAY, order_date)
ORDER BY avg_days_to_ship DESC;
GO

-- Q35: Delete duplicate employees keeping the lowest id (safely)
BEGIN TRAN;
WITH d AS (SELECT emp_id, ROW_NUMBER() OVER (PARTITION BY email ORDER BY emp_id) AS rn FROM dbo.Employees)
DELETE FROM d WHERE rn > 1;
SELECT @@ROWCOUNT AS rows_deleted;
ROLLBACK;   -- use COMMIT in real life
GO

-- Q36: Standardise messy city names
SELECT UPPER(LEFT(TRIM(city), 1)) + LOWER(SUBSTRING(TRIM(city), 2, 100)) AS city_clean, COUNT(*) AS customers
FROM dbo.Customers
GROUP BY UPPER(LEFT(TRIM(city), 1)) + LOWER(SUBSTRING(TRIM(city), 2, 100))
ORDER BY customers DESC;
GO

-- Q37: Split full name into first and last name
SELECT TOP 5 full_name,
       LEFT(full_name, CHARINDEX(' ', full_name + ' ') - 1) AS first_name,
       LTRIM(SUBSTRING(full_name, CHARINDEX(' ', full_name + ' '), 100)) AS last_name
FROM dbo.Employees;
GO

-- Q38: Cancellation rate per customer without divide-by-zero errors
SELECT TOP 10 customer_id,
       SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled, COUNT(*) AS orders,
       CAST(100.0 * SUM(CASE WHEN status = 'Cancelled' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) AS DECIMAL(5,1)) AS cancel_pct
FROM dbo.Orders GROUP BY customer_id ORDER BY cancel_pct DESC, orders DESC;
GO

-- Q39: Upsert a customer summary table with MERGE
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
GO

-- Q40: Revenue by category and quarter (PIVOT)
SELECT category, [1] AS Q1, [2] AS Q2, [3] AS Q3, [4] AS Q4
FROM (
    SELECT p.category, DATEPART(QUARTER, o.order_date) AS qtr, oi.qty * oi.unit_price AS revenue
    FROM dbo.Orders o JOIN dbo.OrderItems oi ON oi.order_id = o.order_id JOIN dbo.Products p ON p.product_id = oi.product_id
    WHERE YEAR(o.order_date) = 2025
) s
PIVOT (SUM(revenue) FOR qtr IN ([1], [2], [3], [4])) pv
ORDER BY category;
GO

-- Q41: Unpivot quarterly targets (wide to long)
SELECT t.dept_id, v.quarter_name, v.target
FROM dbo.Targets t
CROSS APPLY (VALUES ('Q1', t.Q1), ('Q2', t.Q2), ('Q3', t.Q3), ('Q4', t.Q4)) AS v (quarter_name, target)
ORDER BY t.dept_id, v.quarter_name;
GO

-- Q42: Org chart: level and reporting path (recursive CTE)
WITH org AS (
    SELECT emp_id, full_name, manager_id, 0 AS lvl, CAST(full_name AS NVARCHAR(400)) AS path
    FROM dbo.Employees WHERE manager_id IS NULL
    UNION ALL
    SELECT e.emp_id, e.full_name, e.manager_id, o.lvl + 1, CAST(o.path + N' > ' + e.full_name AS NVARCHAR(400))
    FROM dbo.Employees e JOIN org o ON e.manager_id = o.emp_id
)
SELECT TOP 12 emp_id, lvl, path FROM org ORDER BY path;
GO

-- Q43: Pareto: products that make 80% of revenue
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
GO

-- Q44: Customers whose spend grew 3 months in a row
WITH m AS (
    SELECT o.customer_id, DATEFROMPARTS(YEAR(o.order_date), MONTH(o.order_date), 1) AS mo, SUM(oi.qty * oi.unit_price) AS spend
    FROM dbo.Orders o JOIN dbo.OrderItems oi ON oi.order_id = o.order_id
    GROUP BY o.customer_id, DATEFROMPARTS(YEAR(o.order_date), MONTH(o.order_date), 1)
), l AS (
    SELECT *, LAG(spend, 1) OVER (PARTITION BY customer_id ORDER BY mo) AS s1, LAG(spend, 2) OVER (PARTITION BY customer_id ORDER BY mo) AS s2
    FROM m
)
SELECT DISTINCT customer_id FROM l WHERE spend > s1 AND s1 > s2 ORDER BY customer_id;
GO

-- Q45: Department with the highest salary cost (keep ties)
SELECT TOP 1 WITH TIES d.dept_name, SUM(e.salary) AS salary_cost, COUNT(*) AS headcount
FROM dbo.Employees e JOIN dbo.Departments d ON d.dept_id = e.dept_id
GROUP BY d.dept_name
ORDER BY SUM(e.salary) DESC;
GO

-- Q46: Unusually large orders per customer (above mean + 2 standard deviations)
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
GO

-- Q47: Query execution order: why can't WHERE use a SELECT alias?
SELECT full_name, a.annual
FROM dbo.Employees
CROSS APPLY (SELECT salary * 12 AS annual) a
WHERE a.annual > 300000
ORDER BY a.annual DESC;
GO

-- Q48: Index thinking: rewrite a non-sargable filter
SELECT COUNT(*) AS orders_2025
FROM dbo.Orders
WHERE order_date >= '2025-01-01' AND order_date < '2026-01-01';
GO
