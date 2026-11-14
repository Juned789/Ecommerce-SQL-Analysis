-- 04_analysis.sql : business questions. Each block starts with  -- name: <query_name>
-- run_project.py runs every block and saves the result to results/<query_name>.csv

-- name: q01_data_quality_check
-- Q: How many bad rows did cleaning remove?
SELECT 'customers' AS table_name, (SELECT COUNT(*) FROM raw_customers) AS raw_rows, (SELECT COUNT(*) FROM customers) AS clean_rows
UNION ALL SELECT 'orders',      (SELECT COUNT(*) FROM raw_orders),      (SELECT COUNT(*) FROM orders)
UNION ALL SELECT 'order_items', (SELECT COUNT(*) FROM raw_order_items), (SELECT COUNT(*) FROM order_items);

-- name: q02_kpi_summary
-- Q: What are the headline numbers for the business? (INR)
SELECT ROUND(SUM(line_revenue), 0)                          AS total_revenue,
       ROUND(SUM(line_revenue - line_cost), 0)              AS total_profit,
       ROUND(100.0 * SUM(line_revenue - line_cost) / SUM(line_revenue), 1) AS profit_margin_pct,
       COUNT(DISTINCT order_id)                             AS delivered_orders,
       COUNT(DISTINCT customer_id)                          AS active_customers,
       ROUND(SUM(line_revenue) / COUNT(DISTINCT order_id), 0) AS avg_order_value
FROM delivered_sales;

-- name: q03_monthly_revenue_growth
-- Q: How does revenue change month over month? (LAG + running total window functions)
WITH monthly AS (
    SELECT month, ROUND(SUM(line_revenue), 0) AS revenue
    FROM delivered_sales GROUP BY month
)
SELECT month, revenue,
       LAG(revenue) OVER (ORDER BY month) AS prev_month_revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
             / LAG(revenue) OVER (ORDER BY month), 1) AS mom_growth_pct,
       SUM(revenue) OVER (ORDER BY month) AS running_total
FROM monthly;

-- name: q04_top_10_products
-- Q: Which products make the most money?
SELECT product_name, category,
       SUM(quantity)                AS units_sold,
       ROUND(SUM(line_revenue), 0)  AS revenue,
       ROUND(SUM(line_revenue - line_cost), 0) AS profit
FROM delivered_sales
GROUP BY product_id, product_name, category
ORDER BY revenue DESC
LIMIT 10;

-- name: q05_category_profitability
-- Q: Which category has the best profit margin?
SELECT category,
       ROUND(SUM(line_revenue), 0)                 AS revenue,
       ROUND(SUM(line_revenue - line_cost), 0)     AS profit,
       ROUND(100.0 * SUM(line_revenue - line_cost) / SUM(line_revenue), 1) AS margin_pct,
       ROUND(100.0 * SUM(line_revenue) / SUM(SUM(line_revenue)) OVER (), 1) AS revenue_share_pct
FROM delivered_sales
GROUP BY category
ORDER BY revenue DESC;

-- name: q06_city_performance
-- Q: Which cities bring the most revenue and the highest spend per customer?
SELECT c.city,
       COUNT(DISTINCT ds.customer_id)  AS customers,
       COUNT(DISTINCT ds.order_id)     AS orders,
       ROUND(SUM(ds.line_revenue), 0)  AS revenue,
       ROUND(SUM(ds.line_revenue) / COUNT(DISTINCT ds.customer_id), 0) AS revenue_per_customer
FROM delivered_sales ds
JOIN customers c ON c.customer_id = ds.customer_id
GROUP BY c.city
ORDER BY revenue DESC;

-- name: q07_order_status_breakdown
-- Q: What share of orders get cancelled or returned?
SELECT status, COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_orders
FROM orders
GROUP BY status
ORDER BY orders DESC;

-- name: q08_top_3_customers_per_city
-- Q: Who are our best 3 customers in every city? (ROW_NUMBER + PARTITION BY)
WITH spend AS (
    SELECT c.city, c.customer_id, c.customer_name, ROUND(SUM(ds.line_revenue), 0) AS total_spent
    FROM delivered_sales ds
    JOIN customers c ON c.customer_id = ds.customer_id
    GROUP BY c.city, c.customer_id, c.customer_name
),
ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY city ORDER BY total_spent DESC) AS rank_in_city
    FROM spend
)
SELECT city, rank_in_city, customer_name, total_spent
FROM ranked
WHERE rank_in_city <= 3
ORDER BY city, rank_in_city;

-- name: q09_repeat_vs_one_time_customers
-- Q: How many customers come back to buy again?
WITH c AS (
    SELECT customer_id, COUNT(DISTINCT order_id) AS n_orders
    FROM delivered_sales GROUP BY customer_id
)
SELECT CASE WHEN n_orders = 1 THEN 'One-time' ELSE 'Repeat' END AS customer_type,
       COUNT(*) AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_customers
FROM c GROUP BY customer_type;

-- name: q10_rfm_segment_summary
-- Q: How can we group customers for marketing? (RFM = Recency, Frequency, Monetary)
SELECT segment,
       COUNT(*)                   AS customers,
       ROUND(AVG(recency_days), 0) AS avg_days_since_last_order,
       ROUND(AVG(frequency), 1)   AS avg_orders,
       ROUND(AVG(monetary), 0)    AS avg_spend,
       ROUND(SUM(monetary), 0)    AS total_spend
FROM rfm_segments
GROUP BY segment
ORDER BY total_spend DESC;

-- name: q11_festive_vs_regular_season
-- Q: Do Oct-Nov (festive season) months really sell more?
SELECT CASE WHEN CAST(strftime('%m', order_date) AS INTEGER) IN (10, 11) THEN 'Festive (Oct-Nov)' ELSE 'Other months' END AS season,
       COUNT(DISTINCT month) AS months_in_group,
       ROUND(SUM(line_revenue), 0) AS revenue,
       ROUND(SUM(line_revenue) / COUNT(DISTINCT month), 0) AS avg_revenue_per_month
FROM delivered_sales
GROUP BY season;
