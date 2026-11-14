"""
Generates a synthetic (fake but realistic) e-commerce dataset for an Indian online store.
Dirty data is added ON PURPOSE (duplicates, messy text, NULLs, bad quantities)
so we can practise data cleaning in SQL.
Run:  python data/generate_data.py
"""
import csv, os, random
from datetime import date, timedelta

random.seed(42)                       # same data every time -> reproducible
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "raw")
os.makedirs(OUT, exist_ok=True)

CITIES = ["Mumbai", "Delhi", "Bengaluru", "Hyderabad", "Ahmedabad",
          "Chennai", "Kolkata", "Pune", "Jaipur", "Surat"]
CITY_WEIGHTS = [16, 15, 15, 10, 9, 9, 7, 8, 6, 5]
FIRST = ["Aarav","Vivaan","Aditya","Riya","Ananya","Diya","Rohan","Priya","Karan","Neha",
         "Isha","Arjun","Meera","Sahil","Pooja","Kabir","Sneha","Yash","Tanvi","Dev"]
LAST = ["Sharma","Patel","Singh","Gupta","Mehta","Reddy","Nair","Iyer","Shah","Verma"]

CATEGORIES = {
    "Electronics":    [("Wireless Earbuds",1999,1200),("Smart Watch",3499,2200),("Power Bank",1299,750),
                       ("Bluetooth Speaker",2499,1500),("Phone Case",399,120),("USB-C Cable",299,90),
                       ("Gaming Mouse",1499,800),("Laptop Stand",1199,600)],
    "Fashion":        [("Cotton T-Shirt",599,250),("Denim Jeans",1799,900),("Running Shoes",2999,1600),
                       ("Kurta",1299,600),("Sunglasses",999,350),("Backpack",1499,700),("Hoodie",1599,750)],
    "Home & Kitchen": [("Air Fryer",5999,3600),("Non-stick Pan",1099,550),("Bedsheet Set",1499,700),
                       ("Water Bottle",499,180),("LED Lamp",799,350),("Mixer Grinder",3299,2000)],
    "Beauty":         [("Face Wash",299,110),("Moisturiser",549,220),("Perfume",1499,600),
                       ("Hair Oil",349,130),("Sunscreen",499,190),("Lipstick",599,220)],
    "Books":          [("Python Crash Course",699,380),("SQL for Beginners",499,260),("Atomic Habits",399,210),
                       ("Data Science Handbook",899,480),("Novel Collection",599,300)],
    "Sports":         [("Yoga Mat",799,320),("Dumbbell Set",2499,1400),("Football",899,420),
                       ("Cricket Bat",1999,1000),("Skipping Rope",249,80),("Badminton Racket",1299,650)],
}

# ---------- products ----------
products, pid = [], 1
for cat, items in CATEGORIES.items():
    for name, price, cost in items:
        products.append([pid, name, cat, price, cost]); pid += 1

# ---------- customers (1000 + 50 duplicates + messy text) ----------
START, END = date(2024, 1, 1), date(2025, 12, 31)
N_CUST = 1000
customers = []
for cid in range(1, N_CUST + 1):
    name = f"{random.choice(FIRST)} {random.choice(LAST)}"
    city = random.choices(CITIES, CITY_WEIGHTS)[0]
    signup = START + timedelta(days=random.randint(0, 600))
    email = f"{name.lower().replace(' ', '.')}{cid}@example.com"
    r = random.random()
    if r < 0.05:   city = None                     # missing city
    elif r < 0.15: city = city.upper()             # MUMBAI
    elif r < 0.25: city = f"  {city.lower()} "     #   mumbai
    if random.random() < 0.10: email = email.upper()
    customers.append([cid, name, email, city, signup.isoformat()])
customers += random.sample(customers, 50)          # exact duplicate rows

# ---------- orders & items ----------
MONTH_WEIGHT = {1:1.0,2:0.9,3:1.0,4:1.0,5:1.1,6:1.0,7:1.0,8:1.1,9:1.2,10:1.8,11:1.9,12:1.4}  # festive boost
days = [START + timedelta(days=i) for i in range((END - START).days + 1)]
day_w = [MONTH_WEIGHT[d.month] for d in days]

orders, items, oid, iid = [], [], 1, 1
for _ in range(5000):
    cust = random.choice(customers[:N_CUST])
    order_day = random.choices(days, day_w)[0]
    signup_day = date.fromisoformat(cust[4])
    if order_day < signup_day:                      # nobody orders before signing up
        order_day = min(signup_day + timedelta(days=random.randint(0, 30)), END)
    status = random.choices(["delivered", "cancelled", "returned"], [85, 8, 7])[0]
    if random.random() < 0.08: status = status.upper()           # DELIVERED
    elif random.random() < 0.05: status = status.capitalize() + " "
    orders.append([oid, cust[0], order_day.isoformat(), status])
    for _ in range(random.choices([1, 2, 3, 4], [50, 30, 15, 5])[0]):
        p = random.choice(products)
        qty = random.choices([1, 2, 3], [75, 20, 5])[0]
        if random.random() < 0.01: qty = random.choice([0, -1])  # bad quantity
        disc = random.choice([0, 0, 0, 0.05, 0.10, 0.15, 0.20])
        items.append([iid, oid, p[0], qty, p[3], disc]); iid += 1
    oid += 1
orders += random.sample(orders, 60)                              # duplicate orders

def write(name, header, rows):
    with open(os.path.join(OUT, name), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f); w.writerow(header); w.writerows(rows)

write("customers.csv",   ["customer_id","customer_name","email","city","signup_date"], customers)
write("products.csv",    ["product_id","product_name","category","price","cost"], products)
write("orders.csv",      ["order_id","customer_id","order_date","status"], orders)
write("order_items.csv", ["order_item_id","order_id","product_id","quantity","unit_price","discount"], items)
print(f"customers={len(customers)} products={len(products)} orders={len(orders)} order_items={len(items)}")
