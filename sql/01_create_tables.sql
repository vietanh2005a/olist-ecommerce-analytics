-- DESCRIPTION: Create clean relational tables for Olist E-Commerce in SQL Server

IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'OlistEcommerce')
BEGIN
    CREATE DATABASE OlistEcommerce;
END
GO

USE OlistEcommerce;
GO

-- Drop tables if exist (clean slate)
IF OBJECT_ID('dbo.order_reviews', 'U') IS NOT NULL DROP TABLE dbo.order_reviews;
IF OBJECT_ID('dbo.order_payments', 'U') IS NOT NULL DROP TABLE dbo.order_payments;
IF OBJECT_ID('dbo.order_items', 'U') IS NOT NULL DROP TABLE dbo.order_items;
IF OBJECT_ID('dbo.orders', 'U') IS NOT NULL DROP TABLE dbo.orders;
IF OBJECT_ID('dbo.products', 'U') IS NOT NULL DROP TABLE dbo.products;
IF OBJECT_ID('dbo.sellers', 'U') IS NOT NULL DROP TABLE dbo.sellers;
IF OBJECT_ID('dbo.customers', 'U') IS NOT NULL DROP TABLE dbo.customers;
GO

-- 1. Customers Table (Dimension)
CREATE TABLE dbo.customers (
    customer_id VARCHAR(50) NOT NULL PRIMARY KEY,
    customer_unique_id VARCHAR(50) NOT NULL,
    customer_zip_code_prefix INT NULL,
    customer_city NVARCHAR(100) NULL,
    customer_state VARCHAR(5) NULL
);
GO

-- 2. Sellers Table (Dimension)
CREATE TABLE dbo.sellers (
    seller_id VARCHAR(50) NOT NULL PRIMARY KEY,
    seller_zip_code_prefix INT NULL,
    seller_city NVARCHAR(100) NULL,
    seller_state VARCHAR(5) NULL
);
GO

-- 3. Products Table (Dimension)
CREATE TABLE dbo.products (
    product_id VARCHAR(50) NOT NULL PRIMARY KEY,
    product_category_name NVARCHAR(100) NULL,
    product_category_name_english NVARCHAR(100) NULL,
    product_name_length INT NULL,
    product_description_length INT NULL,
    product_photos_qty INT NULL,
    product_weight_g INT NULL,
    product_length_cm INT NULL,
    product_height_cm INT NULL,
    product_width_cm INT NULL
);
GO

-- 4. Orders Table (Fact Table Core)
CREATE TABLE dbo.orders (
    order_id VARCHAR(50) NOT NULL PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    order_status VARCHAR(20) NOT NULL,
    order_purchase_timestamp DATETIME2 NULL,
    order_approved_at DATETIME2 NULL,
    order_delivered_carrier_date DATETIME2 NULL,
    order_delivered_customer_date DATETIME2 NULL,
    order_estimated_delivery_date DATETIME2 NULL
);
GO

-- 5. Order Items Table (Fact Table Detail)
CREATE TABLE dbo.order_items (
    order_id VARCHAR(50) NOT NULL,
    order_item_id INT NOT NULL,
    product_id VARCHAR(50) NOT NULL,
    seller_id VARCHAR(50) NOT NULL,
    shipping_limit_date DATETIME2 NULL,
    price DECIMAL(12, 2) NOT NULL,
    freight_value DECIMAL(12, 2) NOT NULL,
    CONSTRAINT PK_order_items PRIMARY KEY (order_id, order_item_id)
);
GO

-- 6. Order Payments Table (Fact Table Payments)
CREATE TABLE dbo.order_payments (
    order_id VARCHAR(50) NOT NULL,
    payment_sequential INT NOT NULL,
    payment_type VARCHAR(30) NOT NULL,
    payment_installments INT NOT NULL,
    payment_value DECIMAL(12, 2) NOT NULL,
    CONSTRAINT PK_order_payments PRIMARY KEY (order_id, payment_sequential)
);
GO

-- 7. Order Reviews Table (Fact Table Customer Feedback)
CREATE TABLE dbo.order_reviews (
    review_id VARCHAR(50) NOT NULL,
    order_id VARCHAR(50) NOT NULL,
    review_score INT NOT NULL,
    review_comment_title NVARCHAR(255) NULL,
    review_comment_message NVARCHAR(MAX) NULL,
    review_creation_date DATETIME2 NULL,
    review_answer_timestamp DATETIME2 NULL,
    CONSTRAINT PK_order_reviews PRIMARY KEY (review_id, order_id)
);
GO
