"""
Simulated ERP dataset generator
================================
Generates realistic, reproducible transactional data for a fictional Saudi
household & electronics retail chain ("Nakheel Retail") for 2023-01-01 .. 2025-12-31.

The data is SYNTHETIC. It is built to behave like data exported from a real
ERP system (header/detail invoices, purchases, stock movements), including:
  * seasonality  : Ramadan, Eid, back-to-school, White Friday, summer
  * weekly cycle : Thursday / Friday peaks (Saudi weekend)
  * growth trend : +10% 2024, +7% 2025, with one branch declining in 2025
  * a new branch : Makkah opens on 2024-07-01 and ramps up
  * inventory    : simulated day by day -> stock-outs (lost sales) and slow movers
  * customers    : skewed (Pareto-like) spending, joining and churning over time

Outputs (UTF-8 CSV):
  ../01-sales-customer-analysis/data/   normalized ERP tables (loaded into SQL Server)
  ./powerbi_star_schema/   star-schema tables for Power BI

Run:  python generate_erp_data.py
"""
from pathlib import Path
import numpy as np
import pandas as pd

SEED = 42
rng = np.random.default_rng(SEED)

START, END = pd.Timestamp("2023-01-01"), pd.Timestamp("2025-12-31")
DATES = pd.date_range(START, END, freq="D")

ROOT = Path(__file__).resolve().parent.parent
SQL_OUT = ROOT / "01-sales-customer-analysis" / "data"
PBI_OUT = Path(__file__).resolve().parent / "powerbi_star_schema"
SQL_OUT.mkdir(parents=True, exist_ok=True)
PBI_OUT.mkdir(parents=True, exist_ok=True)

# --------------------------------------------------------------------------
# 1. Branches
# --------------------------------------------------------------------------
branches = pd.DataFrame([
    # id, code, name, city, region, open date, size factor
    (1, "JED-01", "Jeddah - Tahlia",  "Jeddah",  "Western", "2015-03-01", 1.30),
    (2, "JED-02", "Jeddah - Al Safa", "Jeddah",  "Western", "2018-09-01", 1.00),
    (3, "RUH-01", "Riyadh - Olaya",   "Riyadh",  "Central", "2016-05-01", 1.40),
    (4, "DMM-01", "Dammam - Corniche", "Dammam", "Eastern", "2019-01-15", 0.85),
    (5, "MKK-01", "Makkah - Al Awali", "Makkah", "Western", "2024-07-01", 0.80),
], columns=["BranchID", "BranchCode", "BranchName", "City", "Region", "OpenDate", "_size"])
branches["OpenDate"] = pd.to_datetime(branches["OpenDate"])

# --------------------------------------------------------------------------
# 2. Suppliers
# --------------------------------------------------------------------------
suppliers = pd.DataFrame([
    (1, "Gulf Mobile Distribution",  "Jeddah",  6),
    (2, "TechSource Arabia",         "Riyadh",  8),
    (3, "Al Rawabi Home Appliances", "Dammam", 10),
    (4, "Kitchen Plus Trading",      "Jeddah",  5),
    (5, "Care & Beauty Wholesale",   "Riyadh",  4),
    (6, "Maktabat Supplies Co.",     "Jeddah",  7),
], columns=["SupplierID", "SupplierName", "City", "LeadTimeDays"])

# --------------------------------------------------------------------------
# 3. Products  (category, subcategory, brand, name, unit cost, base units/day for the chain)
# --------------------------------------------------------------------------
CATALOG = {
    # category: (supplier, [(subcategory, brand, name, cost, daily_units), ...])
    "Mobiles & Accessories": (1, [
        ("Smartphones", "Samsung", "Galaxy A55 128GB", 1150, 1.6),
        ("Smartphones", "Samsung", "Galaxy S24 256GB", 2950, 0.7),
        ("Smartphones", "Apple", "iPhone 15 128GB", 3100, 0.9),
        ("Smartphones", "Apple", "iPhone 13 128GB", 2150, 0.8),   # older model -> slow mover in 2025
        ("Smartphones", "Xiaomi", "Redmi Note 13", 640, 1.8),
        ("Smartphones", "Huawei", "Nova 11", 980, 0.9),
        ("Accessories", "Anker", "20W USB-C Charger", 38, 5.5),
        ("Accessories", "Anker", "Power Bank 10000mAh", 70, 3.6),
        ("Accessories", "Apple", "AirPods (3rd gen)", 560, 1.2),
        ("Accessories", "Generic", "Tempered Glass Screen Protector", 6, 8.0),
        ("Accessories", "Spigen", "Phone Case", 22, 6.5),
        ("Accessories", "Samsung", "Galaxy Buds FE", 260, 1.3),
    ]),
    "Computers": (2, [
        ("Laptops", "Lenovo", "IdeaPad Slim 3 i5", 1850, 0.8),
        ("Laptops", "HP", "Pavilion 15 i7", 2700, 0.5),
        ("Laptops", "Apple", "MacBook Air M2", 3300, 0.4),
        ("Laptops", "Dell", "Inspiron 14 i5 (2022)", 2050, 0.45),   # older model -> slow mover
        ("Tablets", "Apple", "iPad 10th gen", 1350, 0.7),
        ("Tablets", "Samsung", "Galaxy Tab A9", 520, 0.9),
        ("Peripherals", "Logitech", "Wireless Mouse M185", 35, 3.8),
        ("Peripherals", "Logitech", "Keyboard K120", 30, 2.1),
        ("Peripherals", "HP", "LaserJet M111 Printer", 420, 0.4),
        ("Peripherals", "SanDisk", "USB Flash 64GB", 18, 4.2),
    ]),
    "Home Appliances": (3, [
        ("Cooling", "Gree", "Split AC 18000 BTU", 1650, 0.55),
        ("Cooling", "Midea", "Window AC 18000 BTU", 1150, 0.5),
        ("Cooling", "Generic", "Stand Fan 16 inch", 85, 1.6),
        ("Laundry", "LG", "Washing Machine 9kg", 1450, 0.4),
        ("Refrigeration", "Samsung", "Refrigerator 18 cu.ft", 2100, 0.35),
        ("Small Appliances", "Philips", "Vacuum Cleaner 2000W", 330, 0.9),
        ("Small Appliances", "Tefal", "Steam Iron", 95, 1.4),
        ("Small Appliances", "Kenwood", "Water Kettle 1.7L", 60, 2.0),
        ("Small Appliances", "Sharp", "Microwave 25L", 290, 0.8),
        ("Small Appliances", "Black+Decker", "Air Fryer 5L", 230, 1.3),
    ]),
    "Kitchenware": (4, [
        ("Cookware", "Tefal", "Non-stick Pot Set 7pcs", 210, 1.1),
        ("Cookware", "Prestige", "Pressure Cooker 7L", 140, 0.9),
        ("Tableware", "Luminarc", "Dinner Set 38pcs", 180, 0.8),
        ("Tableware", "Generic", "Tea & Coffee Serving Set", 95, 1.6),
        ("Tableware", "Generic", "Arabic Dallah Thermos 1L", 45, 2.4),
        ("Storage", "Tupperware", "Food Storage Set", 65, 1.9),
        ("Utensils", "Generic", "Knife Set 6pcs", 55, 1.2),
        ("Utensils", "Generic", "Serving Tray Large", 40, 1.7),
        ("Small Appliances", "Moulinex", "Blender 1.5L", 150, 1.0),
        ("Small Appliances", "Kenwood", "Stand Mixer", 520, 0.4),
    ]),
    "Personal Care": (5, [
        ("Grooming", "Philips", "Beard Trimmer", 110, 1.4),
        ("Grooming", "Braun", "Electric Shaver Series 5", 330, 0.6),
        ("Hair Care", "Philips", "Hair Dryer 2100W", 95, 1.2),
        ("Hair Care", "BaByliss", "Hair Straightener", 140, 1.0),
        ("Oral Care", "Oral-B", "Electric Toothbrush Pro 3", 150, 0.9),
        ("Fragrance", "Arabian Oud", "Oud Perfume 100ml", 160, 1.3),
        ("Fragrance", "Generic", "Electric Bakhoor Burner", 45, 1.5),
        ("Health", "Omron", "Blood Pressure Monitor", 165, 0.5),
    ]),
    "Stationery & School": (6, [
        ("School Bags", "Generic", "School Backpack", 55, 1.2),
        ("School Bags", "Generic", "Lunch Box Set", 22, 1.4),
        ("Writing", "Faber-Castell", "Colored Pencils 24", 14, 2.2),
        ("Writing", "Pilot", "Pen Pack 10", 9, 3.0),
        ("Paper", "Double A", "A4 Paper Ream", 17, 3.4),
        ("Paper", "Generic", "Notebook Pack 5", 16, 2.6),
        ("Calculators", "Casio", "Scientific Calculator fx-991", 55, 0.9),
        ("Art", "Generic", "Geometry Set", 10, 1.3),
        ("Art", "Generic", "Drawing Kit", 35, 0.7),
        ("Writing", "Generic", "Whiteboard Markers 4", 11, 1.8),
    ]),
}

MARGIN = {  # typical gross margin by category (price = cost / (1 - margin))
    "Mobiles & Accessories": 0.18, "Computers": 0.15, "Home Appliances": 0.24,
    "Kitchenware": 0.38, "Personal Care": 0.35, "Stationery & School": 0.42,
}
ACCESSORY_MARGIN = 0.55   # accessories / peripherals carry much higher margin

rows, pid = [], 1
for cat, (sup, items) in CATALOG.items():
    for sub, brand, name, cost, units in items:
        m = ACCESSORY_MARGIN if sub in ("Accessories", "Peripherals") else MARGIN[cat]
        m = float(np.clip(m + rng.normal(0, 0.03), 0.08, 0.7))
        price = round(cost / (1 - m) / 5) * 5 - 1 if cost > 20 else round(cost / (1 - m), 1)
        rows.append((pid, f"SKU-{pid:04d}", name, cat, sub, brand, sup, float(cost), float(price), units))
        pid += 1
products = pd.DataFrame(rows, columns=["ProductID", "SKU", "ProductName", "Category", "SubCategory",
                                       "Brand", "SupplierID", "StandardCost", "ListPrice", "_units"])
P = len(products)

SLOW_MOVERS = products.loc[products["ProductName"].isin(
    ["iPhone 13 128GB", "Inspiron 14 i5 (2022)", "Stand Mixer", "Drawing Kit", "LaserJet M111 Printer"]),
    "ProductID"].to_numpy()

# --------------------------------------------------------------------------
# 4. Demand model  -> expected units per (day, branch, product)
# --------------------------------------------------------------------------
RAMADAN = {2023: ("2023-03-23", "2023-04-20"), 2024: ("2024-03-11", "2024-04-09"), 2025: ("2025-03-01", "2025-03-29")}
EID = {2023: "2023-04-21", 2024: "2024-04-10", 2025: "2025-03-30"}


def in_window(d, a, b):
    return (d >= pd.Timestamp(a)) & (d <= pd.Timestamp(b))


cat_idx = {c: i for i, c in enumerate(CATALOG)}
C = len(cat_idx)
season = np.ones((len(DATES), C))
d = DATES
for y in (2023, 2024, 2025):
    r0, r1 = RAMADAN[y]
    pre = in_window(d, pd.Timestamp(r0) - pd.Timedelta(days=12), pd.Timestamp(r0) + pd.Timedelta(days=5))
    ram = in_window(d, r0, r1)
    last10 = in_window(d, pd.Timestamp(r1) - pd.Timedelta(days=10), pd.Timestamp(EID[y]) + pd.Timedelta(days=3))
    season[pre, cat_idx["Kitchenware"]] *= 2.2
    season[pre, cat_idx["Home Appliances"]] *= 1.4
    season[ram, cat_idx["Kitchenware"]] *= 1.5
    season[ram, cat_idx["Personal Care"]] *= 1.25
    season[last10, cat_idx["Mobiles & Accessories"]] *= 1.7
    season[last10, cat_idx["Personal Care"]] *= 1.6
    bts = in_window(d, f"{y}-08-08", f"{y}-09-07")
    season[bts, cat_idx["Stationery & School"]] *= 3.5
    season[bts, cat_idx["Computers"]] *= 1.8
    wf = in_window(d, f"{y}-11-14", f"{y}-11-30")
    for c, f in (("Mobiles & Accessories", 2.1), ("Computers", 2.0), ("Home Appliances", 1.7), ("Personal Care", 1.4)):
        season[wf, cat_idx[c]] *= f

month = d.month.to_numpy()
summer = np.isin(month, [5, 6, 7, 8])
winter = np.isin(month, [12, 1, 2])

weekday_f = np.select([d.dayofweek == 3, d.dayofweek == 4, d.dayofweek == 5], [1.25, 1.35, 1.10], 0.88)
years_elapsed = ((d - START).days / 365.25).to_numpy()
trend = np.where(years_elapsed < 1, 1.0 + 0.02 * years_elapsed,
                 np.where(years_elapsed < 2, 1.02 * 1.10 ** (years_elapsed - 1), 1.02 * 1.10 * 1.07 ** (years_elapsed - 2)))

B = len(branches)
branch_f = np.zeros((len(DATES), B))
for i, br in branches.iterrows():
    f = np.full(len(DATES), br["_size"])
    f[d < br["OpenDate"]] = 0.0
    if br["BranchCode"] == "MKK-01":            # ramp-up over the first 9 months
        age = (d - br["OpenDate"]).days.to_numpy()
        f *= np.clip(0.35 + 0.65 * age / 270, 0, 1)
    if br["BranchCode"] == "DMM-01":            # competitor opened nearby in Jan 2025
        f[d >= "2025-01-20"] *= 0.78
    if br["BranchCode"] == "RUH-01":            # strongest growth market
        f *= 1 + 0.06 * np.clip(years_elapsed - 1, 0, None)
    branch_f[:, i] = f

prod_cat = products["Category"].map(cat_idx).to_numpy()
prod_units = products["_units"].to_numpy()
sub = products["SubCategory"].to_numpy()
prod_season = season[:, prod_cat]                                    # (days, P)
prod_season[np.ix_(summer, sub == "Cooling")] *= 2.4                 # AC & fans in summer
prod_season[np.ix_(winter, sub == "Cooling")] *= 0.25
slow_mask = np.isin(products["ProductID"].to_numpy(), SLOW_MOVERS)
decline = np.ones((len(DATES), P))
decline[np.ix_(d >= "2025-01-15", slow_mask)] = 0.12                 # replaced by newer models / fell out of fashion

BRANCH_SHARE = 1 / branches["_size"].sum()
base = (prod_units[None, :] * prod_season * decline * (weekday_f * trend)[:, None])  # (days, P)
expected = base[:, None, :] * branch_f[:, :, None] * BRANCH_SHARE * 2.2              # (days, B, P)

# --------------------------------------------------------------------------
# 5. Inventory simulation (day by day) -> fulfilled units, purchases, snapshots
# --------------------------------------------------------------------------
lead = products["SupplierID"].map(suppliers.set_index("SupplierID")["LeadTimeDays"]).to_numpy()
planned_rate = prod_units[None, :] * branches["_size"].to_numpy()[:, None] * BRANCH_SHARE * 2.2 * 1.05  # (B,P)
reorder_point = np.ceil(planned_rate * (lead[None, :] + 4) * 1.25)
order_qty = np.ceil(np.maximum(planned_rate * 40, 3))

stock = np.where(branches["OpenDate"].to_numpy()[:, None] <= START.to_datetime64(),
                 np.ceil(planned_rate * 45), 0).astype(float)
pipeline = []          # (arrival_day_index, b, p, qty, po_row_index)
po_rows = []
sold = np.zeros((len(DATES), B, P), dtype=np.int32)
lost = np.zeros((len(DATES), B, P), dtype=np.int32)
snapshots = []
year_infl = {2023: 1.00, 2024: 1.03, 2025: 1.055}

# One-off planning mistake: large order of the soon-to-decline models right before the drop
BULK_BUY_DAY = DATES.get_loc(pd.Timestamp("2025-01-06"))

for t, day in enumerate(DATES):
    # receive purchase orders arriving today
    keep = []
    for (arr, b, p, q, ri) in pipeline:
        if arr == t:
            stock[b, p] += q
        else:
            keep.append((arr, b, p, q, ri))
    pipeline = keep

    open_b = branch_f[t] > 0
    # new branch gets opening stock
    for b in np.where((branches["OpenDate"] == day).to_numpy())[0]:
        stock[b] = np.ceil(planned_rate[b] * 30)
        for p in range(P):
            po_rows.append((day - pd.Timedelta(days=int(lead[p]) + 3), day, b, p, stock[b, p]))

    demand = rng.poisson(expected[t])
    fulfilled = np.minimum(demand, stock).astype(np.int32)
    sold[t] = fulfilled
    lost[t] = demand - fulfilled
    stock -= fulfilled

    if t == BULK_BUY_DAY:
        for b in np.where(open_b)[0]:
            for p in np.where(slow_mask)[0]:
                q = float(np.ceil(planned_rate[b, p] * 110))
                pipeline.append((t + int(lead[p]), b, p, q, len(po_rows)))
                po_rows.append((day, day + pd.Timedelta(days=int(lead[p])), b, p, q))

    # reorder (inventory position = on hand + on order)
    on_order = np.zeros((B, P))
    for (arr, b, p, q, ri) in pipeline:
        on_order[b, p] += q
    need = (stock + on_order <= reorder_point) & open_b[:, None]
    # planners stop re-ordering discontinued lines a few months after the decline
    if day >= pd.Timestamp("2025-04-01"):
        need[:, slow_mask] = False
    for b, p in zip(*np.where(need)):
        lt = int(lead[p] + rng.integers(-1, 3))
        if day >= pd.Timestamp("2025-12-05") and products.at[p, "SupplierID"] in (1, 3):
            lt += 18                                   # supplier delay at year end
        q = float(order_qty[b, p] * rng.uniform(0.9, 1.2))
        q = float(np.ceil(q))
        pipeline.append((t + lt, b, p, q, len(po_rows)))
        po_rows.append((day, day + pd.Timedelta(days=lt), b, p, q))

    if day.is_month_end:
        for b in np.where(open_b)[0]:
            for p in range(P):
                snapshots.append((day, b, p, stock[b, p]))

print(f"units sold: {sold.sum():,}   lost (stock-out): {lost.sum():,} ({lost.sum() / (sold.sum() + lost.sum()):.1%})")

# --------------------------------------------------------------------------
# 6. Customers
# --------------------------------------------------------------------------
FIRST = ["Mohammed", "Abdullah", "Ahmed", "Khalid", "Faisal", "Saad", "Omar", "Ali", "Fahad", "Sultan", "Turki",
         "Nasser", "Majed", "Yousef", "Ibrahim", "Hassan", "Nora", "Sara", "Reem", "Fatimah", "Aisha", "Maha",
         "Hessa", "Lama", "Dana", "Abeer", "Hind", "Amal", "Mashael", "Rawan", "Waleed", "Bandar", "Ziyad", "Hamad"]
LAST = ["Al-Harbi", "Al-Ghamdi", "Al-Zahrani", "Al-Qahtani", "Al-Otaibi", "Al-Shehri", "Al-Dosari", "Al-Mutairi",
        "Al-Anazi", "Al-Shammari", "Al-Malki", "Al-Juhani", "Al-Subaie", "Al-Omari", "Al-Hazmi", "Bakr", "Basha",
        "Al-Amoudi", "Al-Sulami", "Al-Thaqafi", "Al-Rashid", "Khayyat", "Al-Faifi", "Hawsawi"]
CO_A = ["Al Noor", "Al Madinah", "Rawabi", "Al Fajr", "Najd", "Al Waha", "Sahara", "Al Bayan", "Al Tamayoz",
        "Masar", "Al Riyada", "Tihama", "Al Khaleej", "Al Yamamah", "Diyar", "Al Majd", "Afaq", "Al Safwa"]
CO_B = ["Trading Co.", "Est.", "Contracting", "Office Solutions", "Hospitality", "Schools", "Medical Center",
        "Real Estate", "Group", "Services"]

N_CUST = 5000
ctype = rng.choice(["Retail", "Wholesale", "Corporate"], N_CUST, p=[0.86, 0.09, 0.05])
city_to_branches = branches.groupby("City")["BranchID"].apply(list).to_dict()
home_branch = rng.choice(branches["BranchID"], N_CUST, p=[0.26, 0.2, 0.27, 0.15, 0.12])
join = START - pd.to_timedelta(rng.integers(0, 900, N_CUST), unit="D")
late = rng.random(N_CUST) < 0.45                                   # 45% join during the period
join = np.where(late, START + pd.to_timedelta(rng.integers(0, len(DATES) - 30, N_CUST), unit="D"), join)
join = pd.to_datetime(join)
mkk = home_branch == 5
join = pd.to_datetime(np.where(mkk & (join < pd.Timestamp("2024-07-01")),
                               pd.Timestamp("2024-07-01") + pd.to_timedelta(rng.integers(0, 400, N_CUST), unit="D"),
                               join))
join = join.where(join <= END - pd.Timedelta(days=10), END - pd.Timedelta(days=10))
churn = pd.to_datetime(np.where(rng.random(N_CUST) < 0.30,
                                join + pd.to_timedelta(rng.integers(120, 800, N_CUST), unit="D"),
                                pd.Timestamp("2100-01-01")))
weight = rng.lognormal(0, 1.1, N_CUST) * np.select([ctype == "Wholesale", ctype == "Corporate"], [3.5, 6], 1)
weight = np.minimum(weight, np.quantile(weight, 0.995))       # no single customer dominates

names = []
for i in range(N_CUST):
    if ctype[i] == "Retail":
        names.append(f"{rng.choice(FIRST)} {rng.choice(LAST)}")
    else:
        names.append(f"{rng.choice(CO_A)} {rng.choice(CO_B)}")
customers = pd.DataFrame({
    "CustomerID": np.arange(1, N_CUST + 1),
    "CustomerName": names,
    "CustomerType": ctype,
    "City": branches.set_index("BranchID").loc[home_branch, "City"].to_numpy(),
    "HomeBranchID": home_branch,
    "JoinDate": join.normalize(),
})
cust_id = customers["CustomerID"].to_numpy()

# --------------------------------------------------------------------------
# 7. Build invoices (header / lines) from fulfilled units
# --------------------------------------------------------------------------
disc_normal = np.array([0, 0, 0, 0.05, 0.10])
inv_rows, line_rows = [], []
inv_id, line_id = 100001, 1
list_price = products["ListPrice"].to_numpy()
std_cost = products["StandardCost"].to_numpy()
is_wf = np.zeros(len(DATES), bool)
for y in (2023, 2024, 2025):
    is_wf |= in_window(DATES, f"{y}-11-14", f"{y}-11-30")

for t, day in enumerate(DATES):
    infl = year_infl[day.year]
    active = (customers["JoinDate"].to_numpy() <= day.to_datetime64()) & (churn.to_numpy() > day.to_datetime64())
    for b in range(B):
        units = sold[t, b]
        if units.sum() == 0:
            continue
        # split units into lines of qty 1..3
        lines = []
        for p in np.nonzero(units)[0]:
            u = int(units[p])
            while u > 0:
                q = int(min(u, rng.choice([1, 1, 1, 1, 2, 2, 3])))
                lines.append((p, q))
                u -= q
        rng.shuffle(lines)
        # group lines into invoices of 1..4 lines
        sizes = []
        remaining = len(lines)
        while remaining > 0:
            s = int(min(remaining, rng.choice([1, 1, 2, 2, 2, 3, 4])))
            sizes.append(s)
            remaining -= s
        home = active & (home_branch == b + 1)
        pool_w = np.where(home, weight, np.where(active, weight * 0.04, 0))
        pool_w = pool_w / pool_w.sum()
        custs = rng.choice(cust_id, len(sizes), p=pool_w)
        pos = 0
        for s, c in zip(sizes, custs):
            typ = ctype[c - 1]
            pay = rng.choice(["Mada", "Cash", "Credit Card", "Apple Pay"], p=[0.45, 0.22, 0.13, 0.20])
            if typ != "Retail" and rng.random() < 0.6:
                pay = "On Account"
            inv_rows.append((inv_id, day, b + 1, int(c), pay))
            for p, q in lines[pos:pos + s]:
                price = round(list_price[p] * infl, 2)
                disc = rng.choice([0.10, 0.15, 0.20]) if is_wf[t] and rng.random() < 0.7 else rng.choice(disc_normal)
                if typ != "Retail":
                    disc = max(disc, 0.05)
                cost = round(std_cost[p] * infl, 2)
                line_rows.append((line_id, inv_id, p + 1, q, price, disc, round(q * price * (1 - disc), 2), cost))
                line_id += 1
            pos += s
            inv_id += 1

invoices = pd.DataFrame(inv_rows, columns=["InvoiceID", "InvoiceDate", "BranchID", "CustomerID", "PaymentMethod"])
lines = pd.DataFrame(line_rows, columns=["LineID", "InvoiceID", "ProductID", "Quantity", "UnitPrice",
                                         "DiscountPct", "NetAmount", "UnitCost"])
print(f"invoices: {len(invoices):,}   lines: {len(lines):,}   net sales: {lines['NetAmount'].sum():,.0f} SAR")

# purchases
purch = pd.DataFrame(po_rows, columns=["OrderDate", "ReceiptDate", "_b", "_p", "Quantity"])
purch = purch[purch["OrderDate"] <= END].sort_values(["OrderDate", "_b", "_p"]).reset_index(drop=True)
purch.insert(0, "PurchaseID", np.arange(1, len(purch) + 1))
purch["BranchID"] = purch["_b"] + 1
purch["ProductID"] = purch["_p"] + 1
purch["SupplierID"] = products.loc[purch["_p"], "SupplierID"].to_numpy()
purch["UnitCost"] = (std_cost[purch["_p"]] * purch["OrderDate"].dt.year.map(year_infl).clip(lower=1.0).to_numpy()
                     * rng.uniform(0.97, 1.03, len(purch))).round(2)
purch["ReceiptDate"] = purch["ReceiptDate"].where(purch["ReceiptDate"] <= END)   # not yet received -> NULL
purch["Quantity"] = purch["Quantity"].astype(int)
purch = purch[["PurchaseID", "OrderDate", "ReceiptDate", "BranchID", "SupplierID", "ProductID", "Quantity", "UnitCost"]]

# inventory snapshots
snap = pd.DataFrame(snapshots, columns=["SnapshotDate", "_b", "_p", "QtyOnHand"])
snap["BranchID"] = snap["_b"] + 1
snap["ProductID"] = snap["_p"] + 1
snap["QtyOnHand"] = snap["QtyOnHand"].astype(int)
snap["UnitCost"] = (std_cost[snap["_p"]] * snap["SnapshotDate"].dt.year.map(year_infl).to_numpy()).round(2)
snap["StockValue"] = (snap["QtyOnHand"] * snap["UnitCost"]).round(2)
snap = snap[["SnapshotDate", "BranchID", "ProductID", "QtyOnHand", "UnitCost", "StockValue"]]

# reorder levels (per branch-product) for "near stock-out" logic in Power BI
reorder = pd.DataFrame([(b + 1, p + 1, int(reorder_point[b, p])) for b in range(B) for p in range(P)],
                       columns=["BranchID", "ProductID", "ReorderLevel"])

# monthly sales targets per branch
fact = lines.merge(invoices[["InvoiceID", "InvoiceDate", "BranchID"]], on="InvoiceID")
fact["Month"] = fact["InvoiceDate"].dt.to_period("M").dt.to_timestamp()
monthly = fact.groupby(["BranchID", "Month"])["NetAmount"].sum()
tgt_rows = []
for b in branches["BranchID"]:
    for m in pd.date_range("2023-01-01", "2025-12-01", freq="MS"):
        prev = monthly.get((b, m - pd.DateOffset(years=1)))
        cur = monthly.get((b, m))
        if cur is None:
            continue
        if prev is None or prev < cur * 0.6:          # no history (2023 / new branch): plan from a rough estimate
            target = cur * rng.uniform(0.92, 1.12)
        else:
            target = prev * 1.10                       # management asks for +10% YoY
        tgt_rows.append((b, m, round(target, -3)))
targets = pd.DataFrame(tgt_rows, columns=["BranchID", "MonthStart", "TargetAmount"])

# --------------------------------------------------------------------------
# 8. Write files
# --------------------------------------------------------------------------
br_out = branches.drop(columns="_size")
pr_out = products.drop(columns="_units")
date_fmt = "%Y-%m-%d"

def w(df, folder, name):
    df.to_csv(folder / name, index=False, encoding="utf-8", date_format=date_fmt, lineterminator="\n")

# normalized ERP tables for SQL Server
w(br_out, SQL_OUT, "Branches.csv")
w(suppliers, SQL_OUT, "Suppliers.csv")
w(pr_out, SQL_OUT, "Products.csv")
w(customers, SQL_OUT, "Customers.csv")
w(invoices, SQL_OUT, "SalesInvoices.csv")
w(lines, SQL_OUT, "SalesInvoiceLines.csv")
w(purch, SQL_OUT, "Purchases.csv")

# star schema for Power BI
fact_sales = fact.merge(invoices[["InvoiceID", "CustomerID"]], on="InvoiceID")
fact_sales = fact_sales.assign(
    GrossAmount=(fact_sales["Quantity"] * fact_sales["UnitPrice"]).round(2),
    CostAmount=(fact_sales["Quantity"] * fact_sales["UnitCost"]).round(2),
)[["LineID", "InvoiceID", "InvoiceDate", "BranchID", "CustomerID", "ProductID", "Quantity",
   "UnitPrice", "DiscountPct", "GrossAmount", "NetAmount", "CostAmount"]]
fact_sales = fact_sales.rename(columns={"InvoiceDate": "Date"})
w(fact_sales, PBI_OUT, "FactSales.csv")
w(purch.rename(columns={"OrderDate": "Date"}), PBI_OUT, "FactPurchases.csv")
w(snap.rename(columns={"SnapshotDate": "Date"}), PBI_OUT, "FactInventory.csv")
w(targets.rename(columns={"MonthStart": "Date"}), PBI_OUT, "FactTargets.csv")
w(br_out, PBI_OUT, "DimBranch.csv")
w(pr_out.merge(suppliers[["SupplierID", "SupplierName"]], on="SupplierID"), PBI_OUT, "DimProduct.csv")
w(customers, PBI_OUT, "DimCustomer.csv")
w(reorder, PBI_OUT, "ReorderLevels.csv")

print("done ->", SQL_OUT, "|", PBI_OUT)
