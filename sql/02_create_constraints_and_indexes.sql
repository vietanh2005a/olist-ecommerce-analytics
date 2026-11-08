-- DESCRIPTION: Enforce Foreign Key integrity and Non-clustered Indexes for query speed

USE OlistEcommerce;
GO

-- 1. FOREIGN KEY CONSTRAINTS
ALTER TABLE dbo.orders 
ADD CONSTRAINT FK_orders_customers FOREIGN KEY (customer_id) REFERENCES dbo.customers(customer_id);

ALTER TABLE dbo.order_items 
ADD CONSTRAINT FK_order_items_orders FOREIGN KEY (order_id) REFERENCES dbo.orders(order_id);

ALTER TABLE dbo.order_items 
ADD CONSTRAINT FK_order_items_products FOREIGN KEY (product_id) REFERENCES dbo.products(product_id);

ALTER TABLE dbo.order_items 
ADD CONSTRAINT FK_order_items_sellers FOREIGN KEY (seller_id) REFERENCES dbo.sellers(seller_id);

ALTER TABLE dbo.order_payments 
ADD CONSTRAINT FK_order_payments_orders FOREIGN KEY (order_id) REFERENCES dbo.orders(order_id);

ALTER TABLE dbo.order_reviews 
ADD CONSTRAINT FK_order_reviews_orders FOREIGN KEY (order_id) REFERENCES dbo.orders(order_id);
GO

-- 2. NON-CLUSTERED INDEXES (Optimizing Analytical Queries)
CREATE NONCLUSTERED INDEX idx_customers_unique_id 
ON dbo.customers(customer_unique_id);

CREATE NONCLUSTERED INDEX idx_orders_purchase_timestamp 
ON dbo.orders(order_purchase_timestamp);

CREATE NONCLUSTERED INDEX idx_orders_status 
ON dbo.orders(order_status);

CREATE NONCLUSTERED INDEX idx_order_reviews_score 
ON dbo.order_reviews(review_score);

CREATE NONCLUSTERED INDEX idx_products_category 
ON dbo.products(product_category_name_english);
GO

-- 3. AUDIT ROW COUNTS ACROSS ALL TABLES
SELECT 
    t.name AS table_name,
    p.rows AS total_records
FROM sys.tables t
INNER JOIN sys.partitions p ON t.object_id = p.object_id
WHERE p.index_id IN (0, 1)
ORDER BY p.rows DESC;
GO
