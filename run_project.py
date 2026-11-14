"""
Runs the whole project end to end:
  1. loads raw CSVs into a SQLite database
  2. runs the SQL files (schema -> cleaning -> views)
  3. runs every analysis query, saves results as CSV
  4. makes 3 charts
Usage:  python run_project.py
"""
import os, re, sqlite3
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(ROOT, "ecommerce.db")
RAW = os.path.join(ROOT, "data", "raw")
RES = os.path.join(ROOT, "results")
CHARTS = os.path.join(RES, "charts")
os.makedirs(CHARTS, exist_ok=True)

def read_sql_file(name):
    with open(os.path.join(ROOT, "sql", name), encoding="utf-8") as f:
        return f.read()

# ---- 1 & 2: build database ----
if os.path.exists(DB): os.remove(DB)
con = sqlite3.connect(DB)
con.executescript(read_sql_file("01_schema.sql"))
for table in ["customers", "products", "orders", "order_items"]:
    pd.read_csv(os.path.join(RAW, f"{table}.csv")).to_sql(f"raw_{table}", con, if_exists="append", index=False)
con.executescript(read_sql_file("02_cleaning.sql"))
con.executescript(read_sql_file("03_views.sql"))
print("Database built and cleaned.\n")

# ---- 3: run analysis queries ----
blocks = re.split(r"^-- name:\s*(\w+)\s*$", read_sql_file("04_analysis.sql"), flags=re.M)
results = {}
for name, sql in zip(blocks[1::2], blocks[2::2]):
    df = pd.read_sql_query(sql, con)
    df.to_csv(os.path.join(RES, f"{name}.csv"), index=False)
    results[name] = df
    print(f"=== {name} ===\n{df.to_string(index=False)}\n")

# ---- 4: charts ----
plt.rcParams.update({"figure.dpi": 130, "axes.spines.top": False, "axes.spines.right": False})

m = results["q03_monthly_revenue_growth"]
fig, ax = plt.subplots(figsize=(10, 4.5))
ax.plot(m["month"], m["revenue"] / 1e5, marker="o", color="#2563eb")
ax.set_title("Monthly Revenue (Delivered Orders)"); ax.set_ylabel("Revenue (INR lakh)")
ax.set_xticks(range(0, len(m), 2)); ax.set_xticklabels(m["month"][::2], rotation=45)
fig.tight_layout(); fig.savefig(os.path.join(CHARTS, "monthly_revenue.png")); plt.close(fig)

c = results["q05_category_profitability"]
fig, ax = plt.subplots(figsize=(8, 4.5))
ax.bar(c["category"], c["profit"] / 1e5, color="#16a34a")
for i, v in enumerate(c["margin_pct"]): ax.text(i, c["profit"].iloc[i] / 1e5, f"{v}%", ha="center", va="bottom", fontsize=9)
ax.set_title("Profit by Category (label = profit margin)"); ax.set_ylabel("Profit (INR lakh)")
plt.xticks(rotation=20); fig.tight_layout(); fig.savefig(os.path.join(CHARTS, "category_profit.png")); plt.close(fig)

s = results["q10_rfm_segment_summary"]
fig, ax = plt.subplots(figsize=(7, 4.5))
ax.barh(s["segment"], s["customers"], color="#f59e0b"); ax.invert_yaxis()
ax.set_title("Customers per RFM Segment"); ax.set_xlabel("Number of customers")
fig.tight_layout(); fig.savefig(os.path.join(CHARTS, "rfm_segments.png")); plt.close(fig)

con.close()
print("Done. See the results/ folder.")
