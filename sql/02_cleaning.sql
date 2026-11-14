-- 02_cleaning.sql : turn RAW tables into CLEAN tables
-- Issues found during exploration:
--   customers   -> duplicate rows, city in mixed case / extra spaces / NULL, UPPERCASE emails
--   orders      -> duplicate order_id rows, status has mixed case & trailing spaces
--   order_items -> quantity <= 0 (invalid)

DROP TABLE IF EXISTS customers;
CREATE TABLE customers AS
SELECT customer_id,
       TRIM(customer_name)  AS customer_name,
       LOWER(TRIM(email))   AS email,
       CASE WHEN city IS NULL OR TRIM(city) = '' THEN 'Unknown'
            ELSE UPPER(SUBSTR(TRIM(city), 1, 1)) || LOWER(SUBSTR(TRIM(city), 2))
       END                  AS city,
       signup_date
FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY signup_date) AS rn
      FROM raw_customers)
WHERE rn = 1;                                   -- keep one row per customer

DROP TABLE IF EXISTS products;
CREATE TABLE products AS SELECT * FROM raw_products;

DROP TABLE IF EXISTS orders;
CREATE TABLE orders AS
SELECT order_id, customer_id, order_date, LOWER(TRIM(status)) AS status
FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY order_date) AS rn
      FROM raw_orders)
WHERE rn = 1;

DROP TABLE IF EXISTS order_items;
CREATE TABLE order_items AS
SELECT order_item_id, order_id, product_id, quantity, unit_price, discount,
       ROUND(quantity * unit_price * (1 - discount), 2) AS line_revenue
FROM raw_order_items
WHERE quantity > 0;                              -- drop invalid quantities
