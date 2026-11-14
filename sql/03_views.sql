-- 03_views.sql : reusable "virtual tables" so analysis queries stay short.

DROP VIEW IF EXISTS delivered_sales;
CREATE VIEW delivered_sales AS
SELECT oi.order_item_id, oi.order_id, o.customer_id, o.order_date,
       strftime('%Y-%m', o.order_date)  AS month,
       p.product_id, p.product_name, p.category,
       oi.quantity, oi.line_revenue,
       oi.quantity * p.cost             AS line_cost
FROM order_items oi
JOIN orders   o ON o.order_id   = oi.order_id
JOIN products p ON p.product_id = oi.product_id
WHERE o.status = 'delivered';                    -- only delivered orders count as revenue

DROP VIEW IF EXISTS rfm_segments;
CREATE VIEW rfm_segments AS
WITH cust AS (
    SELECT customer_id,
           MAX(order_date)           AS last_order,
           COUNT(DISTINCT order_id)  AS frequency,
           SUM(line_revenue)         AS monetary
    FROM delivered_sales
    GROUP BY customer_id
),
scored AS (
    SELECT *,
           CAST(julianday('2025-12-31') - julianday(last_order) AS INTEGER) AS recency_days,
           NTILE(4) OVER (ORDER BY julianday(last_order)) AS r,   -- 4 = most recent
           NTILE(4) OVER (ORDER BY frequency, monetary)   AS f,   -- 4 = most frequent
           NTILE(4) OVER (ORDER BY monetary)              AS m    -- 4 = biggest spender
    FROM cust
)
SELECT customer_id, recency_days, frequency, ROUND(monetary, 0) AS monetary, r, f, m,
       CASE WHEN r >= 3 AND f >= 3 AND m >= 3 THEN 'Champions'
            WHEN r >= 3 AND f >= 2             THEN 'Loyal'
            WHEN r <= 2 AND f >= 3             THEN 'At Risk'
            WHEN r = 1  AND f <= 2             THEN 'Lost'
            ELSE 'Regular'
       END AS segment
FROM scored;
