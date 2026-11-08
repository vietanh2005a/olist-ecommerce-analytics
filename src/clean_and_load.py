"""
ETL Pipeline: Clean and Load Olist E-Commerce raw datasets into SQL Server.
Applies transformations specified in EDA notebook and uses fast bulk insertion.
"""
import os
import time
import pandas as pd
import numpy as np
import pyodbc

DATA_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data", "raw")
CONN_STR = (
    "Driver={ODBC Driver 17 for SQL Server};"
    "Server=.\\SQLEXPRESS;"
    "Database=OlistEcommerce;"
    "Trusted_Connection=yes;"
)

def format_date_str(val):
    if pd.isna(val) or val is None or str(val).strip() == "" or str(val) == "NaT":
        return None
    return str(val)[:19]

def clean_row(val):
    if pd.isna(val) or val is None:
        return None
    s = str(val)
    if s.lower() == "nan" or s == "NaT":
        return None
    return val

def run_etl():
    print("=" * 60)
    print("STARTING ETL PIPELINE -> SQL SERVER (OlistEcommerce)")
    print("=" * 60)
    
    conn = pyodbc.connect(CONN_STR)
    cursor = conn.cursor()
    cursor.fast_executemany = True
    
    total_start = time.time()

    # 1. SELLERS
    t0 = time.time()
    print("[1/7] Processing Sellers...")
    df_sellers = pd.read_csv(os.path.join(DATA_DIR, "olist_sellers_dataset.csv"))
    df_sellers["seller_city"] = df_sellers["seller_city"].astype(str).str.title()
    df_sellers["seller_state"] = df_sellers["seller_state"].astype(str).str.upper()
    df_sellers = df_sellers.drop_duplicates(subset=["seller_id"])
    
    cursor.execute("TRUNCATE TABLE dbo.sellers;")
    data_sellers = [
        (r.seller_id, int(r.seller_zip_code_prefix) if pd.notna(r.seller_zip_code_prefix) else None, r.seller_city, r.seller_state)
        for r in df_sellers.itertuples(index=False)
    ]
    cursor.executemany("INSERT INTO dbo.sellers VALUES (?, ?, ?, ?)", data_sellers)
    conn.commit()
    print(f"      -> Loaded {len(data_sellers):,} sellers ({time.time() - t0:.2f}s)")

    # 2. CUSTOMERS
    t0 = time.time()
    print("[2/7] Processing Customers...")
    df_cust = pd.read_csv(os.path.join(DATA_DIR, "olist_customers_dataset.csv"))
    df_cust["customer_city"] = df_cust["customer_city"].astype(str).str.title()
    df_cust["customer_state"] = df_cust["customer_state"].astype(str).str.upper()
    df_cust = df_cust.drop_duplicates(subset=["customer_id"])
    
    cursor.execute("TRUNCATE TABLE dbo.customers;")
    data_cust = [
        (r.customer_id, r.customer_unique_id, int(r.customer_zip_code_prefix) if pd.notna(r.customer_zip_code_prefix) else None, r.customer_city, r.customer_state)
        for r in df_cust.itertuples(index=False)
    ]
    cursor.executemany("INSERT INTO dbo.customers VALUES (?, ?, ?, ?, ?)", data_cust)
    conn.commit()
    print(f"      -> Loaded {len(data_cust):,} customers ({time.time() - t0:.2f}s)")

    # 3. PRODUCTS
    t0 = time.time()
    print("[3/7] Processing Products...")
    df_prod = pd.read_csv(os.path.join(DATA_DIR, "olist_products_dataset.csv"))
    df_trans = pd.read_csv(os.path.join(DATA_DIR, "product_category_name_translation.csv"))
    
    df_prod = df_prod.rename(columns={
        "product_name_lenght": "product_name_length",
        "product_description_lenght": "product_description_length"
    })
    df_prod = df_prod.merge(df_trans, on="product_category_name", how="left")
    df_prod["product_category_name_english"] = df_prod["product_category_name_english"].fillna("Other / Unknown").str.replace("_", " ").str.title()
    df_prod = df_prod.drop_duplicates(subset=["product_id"])
    
    cursor.execute("TRUNCATE TABLE dbo.products;")
    data_prod = [
        (
            r.product_id,
            clean_row(r.product_category_name),
            r.product_category_name_english,
            int(r.product_name_length) if pd.notna(r.product_name_length) else None,
            int(r.product_description_length) if pd.notna(r.product_description_length) else None,
            int(r.product_photos_qty) if pd.notna(r.product_photos_qty) else None,
            int(r.product_weight_g) if pd.notna(r.product_weight_g) else None,
            int(r.product_length_cm) if pd.notna(r.product_length_cm) else None,
            int(r.product_height_cm) if pd.notna(r.product_height_cm) else None,
            int(r.product_width_cm) if pd.notna(r.product_width_cm) else None
        )
        for r in df_prod.itertuples(index=False)
    ]
    cursor.executemany("INSERT INTO dbo.products VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", data_prod)
    conn.commit()
    print(f"      -> Loaded {len(data_prod):,} products ({time.time() - t0:.2f}s)")

    # 4. ORDERS
    t0 = time.time()
    print("[4/7] Processing Orders...")
    df_orders = pd.read_csv(os.path.join(DATA_DIR, "olist_orders_dataset.csv"))
    df_orders = df_orders.drop_duplicates(subset=["order_id"])
    
    cursor.execute("TRUNCATE TABLE dbo.orders;")
    data_orders = [
        (
            r.order_id,
            r.customer_id,
            r.order_status,
            format_date_str(r.order_purchase_timestamp),
            format_date_str(r.order_approved_at),
            format_date_str(r.order_delivered_carrier_date),
            format_date_str(r.order_delivered_customer_date),
            format_date_str(r.order_estimated_delivery_date)
        )
        for r in df_orders.itertuples(index=False)
    ]
    cursor.executemany("INSERT INTO dbo.orders VALUES (?, ?, ?, ?, ?, ?, ?, ?)", data_orders)
    conn.commit()
    print(f"      -> Loaded {len(data_orders):,} orders ({time.time() - t0:.2f}s)")

    # 5. ORDER ITEMS
    t0 = time.time()
    print("[5/7] Processing Order Items...")
    df_items = pd.read_csv(os.path.join(DATA_DIR, "olist_order_items_dataset.csv"))
    df_items = df_items.drop_duplicates(subset=["order_id", "order_item_id"])
    
    cursor.execute("TRUNCATE TABLE dbo.order_items;")
    data_items = [
        (
            r.order_id,
            int(r.order_item_id),
            r.product_id,
            r.seller_id,
            format_date_str(r.shipping_limit_date),
            round(float(r.price), 2),
            round(float(r.freight_value), 2)
        )
        for r in df_items.itertuples(index=False)
    ]
    cursor.executemany("INSERT INTO dbo.order_items VALUES (?, ?, ?, ?, ?, ?, ?)", data_items)
    conn.commit()
    print(f"      -> Loaded {len(data_items):,} order items ({time.time() - t0:.2f}s)")

    # 6. ORDER PAYMENTS
    t0 = time.time()
    print("[6/7] Processing Order Payments...")
    df_pay = pd.read_csv(os.path.join(DATA_DIR, "olist_order_payments_dataset.csv"))
    df_pay = df_pay.drop_duplicates(subset=["order_id", "payment_sequential"])
    
    cursor.execute("TRUNCATE TABLE dbo.order_payments;")
    data_pay = [
        (
            r.order_id,
            int(r.payment_sequential),
            r.payment_type,
            int(r.payment_installments),
            round(float(r.payment_value), 2)
        )
        for r in df_pay.itertuples(index=False)
    ]
    cursor.executemany("INSERT INTO dbo.order_payments VALUES (?, ?, ?, ?, ?)", data_pay)
    conn.commit()
    print(f"      -> Loaded {len(data_pay):,} payments ({time.time() - t0:.2f}s)")

    # 7. ORDER REVIEWS
    t0 = time.time()
    print("[7/7] Processing Order Reviews...")
    df_rev = pd.read_csv(os.path.join(DATA_DIR, "olist_order_reviews_dataset.csv"))
    df_rev = df_rev.drop_duplicates(subset=["review_id", "order_id"])
    
    cursor.execute("TRUNCATE TABLE dbo.order_reviews;")
    data_rev = []
    for r in df_rev.itertuples(index=False):
        title = clean_row(r.review_comment_title)
        if title:
            title = str(title)[:250]
        msg = clean_row(r.review_comment_message)
        if msg:
            msg = str(msg)[:4000]
        data_rev.append((
            r.review_id,
            r.order_id,
            int(r.review_score),
            title,
            msg,
            format_date_str(r.review_creation_date),
            format_date_str(r.review_answer_timestamp)
        ))
        
    cursor.executemany("INSERT INTO dbo.order_reviews VALUES (?, ?, ?, ?, ?, ?, ?)", data_rev)
    conn.commit()
    print(f"      -> Loaded {len(data_rev):,} reviews ({time.time() - t0:.2f}s)")

    conn.close()
    print("=" * 60)
    print(f"ETL COMPLETED SUCCESSFULLY IN {time.time() - total_start:.2f} SECONDS!")
    print("=" * 60)

if __name__ == "__main__":
    run_etl()
