-- 01_schema.sql : RAW tables (data exactly as received, untouched)
-- Rule of data engineering: never edit raw data. Clean it into NEW tables.
DROP TABLE IF EXISTS raw_customers;
DROP TABLE IF EXISTS raw_products;
DROP TABLE IF EXISTS raw_orders;
DROP TABLE IF EXISTS raw_order_items;

CREATE TABLE raw_customers   (customer_id INTEGER, customer_name TEXT, email TEXT, city TEXT, signup_date TEXT);
CREATE TABLE raw_products    (product_id INTEGER, product_name TEXT, category TEXT, price REAL, cost REAL);
CREATE TABLE raw_orders      (order_id INTEGER, customer_id INTEGER, order_date TEXT, status TEXT);
CREATE TABLE raw_order_items (order_item_id INTEGER, order_id INTEGER, product_id INTEGER,
                              quantity INTEGER, unit_price REAL, discount REAL);
