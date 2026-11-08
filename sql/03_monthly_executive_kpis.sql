-- DESCRIPTION: Comprehensive Monthly Executive, Growth & Unit Economics Metrics in T-SQL

USE OlistEcommerce;
GO

CREATE OR ALTER VIEW dbo.vw_monthly_executive_kpis AS
WITH Base_Orders AS (
    SELECT 
        o.order_id,
        o.customer_id,
        c.customer_unique_id,
        o.order_status,
        o.order_purchase_timestamp,
        DATEFROMPARTS(YEAR(o.order_purchase_timestamp), MONTH(o.order_purchase_timestamp), 1) AS sales_month
    FROM dbo.orders o
    INNER JOIN dbo.customers c ON o.customer_id = c.customer_id
    WHERE o.order_purchase_timestamp >= '2017-01-01' 
      AND o.order_purchase_timestamp <= '2018-08-31'
),
Order_Items_Agg AS (
    SELECT 
        order_id,
        COUNT(order_item_id) AS total_items,
        SUM(price) AS gmv,
        SUM(freight_value) AS freight_revenue,
        SUM(price + freight_value) AS net_revenue
    FROM dbo.order_items
    GROUP BY order_id
),
First_Purchase AS (
    -- Customer's earliest order date in history
    SELECT 
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp) AS first_order_date
    FROM dbo.orders o
    INNER JOIN dbo.customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
),
Monthly_Aggregates AS (
    SELECT 
        bo.sales_month,
        -- Volume Metrics
        COUNT(DISTINCT bo.order_id) AS total_orders,
        COUNT(DISTINCT CASE WHEN bo.order_status = 'delivered' THEN bo.order_id END) AS delivered_orders,
        COUNT(DISTINCT CASE WHEN bo.order_status = 'canceled' THEN bo.order_id END) AS canceled_orders,
        COUNT(DISTINCT bo.customer_unique_id) AS unique_active_customers,
        SUM(oia.total_items) AS total_items_sold,
        
        -- Orders that actually generated revenue
        COUNT(DISTINCT CASE WHEN oia.net_revenue > 0 THEN bo.order_id END) AS revenue_orders,
        
        -- Financial Metrics
        ROUND(SUM(oia.gmv), 2) AS gross_merchandise_value,
        ROUND(SUM(oia.freight_revenue), 2) AS total_freight_revenue,
        ROUND(SUM(oia.net_revenue), 2) AS total_net_revenue,
        
        -- Customer Acquisition (New vs Repeat Customers)
        COUNT(DISTINCT CASE WHEN DATEFROMPARTS(YEAR(fp.first_order_date), MONTH(fp.first_order_date), 1) = bo.sales_month THEN bo.customer_unique_id END) AS new_customers,
        COUNT(DISTINCT CASE WHEN DATEFROMPARTS(YEAR(fp.first_order_date), MONTH(fp.first_order_date), 1) < bo.sales_month THEN bo.customer_unique_id END) AS repeat_customers
    FROM Base_Orders bo
    LEFT JOIN Order_Items_Agg oia ON bo.order_id = oia.order_id
    LEFT JOIN First_Purchase fp ON bo.customer_unique_id = fp.customer_unique_id
    GROUP BY bo.sales_month
),
Calculated_Metrics AS (
    SELECT 
        sales_month,
        total_orders,
        delivered_orders,
        canceled_orders,
        CAST(canceled_orders * 100.0 / total_orders AS DECIMAL(5, 2)) AS cancellation_rate_pct,
        unique_active_customers,
        total_items_sold,
        CAST(total_items_sold * 1.0 / NULLIF(delivered_orders, 0) AS DECIMAL(4, 2)) AS basket_size_units_per_order,
        gross_merchandise_value,
        total_freight_revenue,
        total_net_revenue,
        CAST(total_freight_revenue * 100.0 / NULLIF(gross_merchandise_value, 0) AS DECIMAL(5, 2)) AS freight_to_gmv_ratio_pct,
        
        -- AOV calculated on delivered orders generating revenue (True Basket Value)
        CAST(total_net_revenue / NULLIF(delivered_orders, 0) AS DECIMAL(10, 2)) AS average_order_value_aov,
        CAST(gross_merchandise_value / NULLIF(total_items_sold, 0) AS DECIMAL(10, 2)) AS avg_item_price,
        
        new_customers,
        repeat_customers,
        CAST(repeat_customers * 100.0 / unique_active_customers AS DECIMAL(5, 2)) AS repeat_customer_rate_pct,
        
        -- Window Functions: MoM Growth, Cumulative Revenue & Moving Average
        LAG(total_net_revenue, 1) OVER (ORDER BY sales_month) AS prev_month_revenue,
        CAST(
            (total_net_revenue - LAG(total_net_revenue, 1) OVER (ORDER BY sales_month)) * 100.0 / 
            NULLIF(LAG(total_net_revenue, 1) OVER (ORDER BY sales_month), 0) 
            AS DECIMAL(5, 2)
        ) AS mom_revenue_growth_pct,
        
        CAST(
            (delivered_orders - LAG(delivered_orders, 1) OVER (ORDER BY sales_month)) * 100.0 / 
            NULLIF(LAG(delivered_orders, 1) OVER (ORDER BY sales_month), 0) 
            AS DECIMAL(5, 2)
        ) AS mom_order_growth_pct,
        
        SUM(total_net_revenue) OVER (ORDER BY sales_month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_revenue_to_date,
        
        ROUND(
            AVG(total_net_revenue) OVER (ORDER BY sales_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),
            2
        ) AS moving_avg_3m_revenue
    FROM Monthly_Aggregates
)
SELECT * FROM Calculated_Metrics;
GO

-- Display result sample
SELECT 
    sales_month,
    total_orders,
    delivered_orders,
    cancellation_rate_pct,
    total_net_revenue,
    average_order_value_aov,
    basket_size_units_per_order,
    freight_to_gmv_ratio_pct,
    mom_revenue_growth_pct,
    repeat_customer_rate_pct,
    cumulative_revenue_to_date,
    moving_avg_3m_revenue
FROM dbo.vw_monthly_executive_kpis
ORDER BY sales_month;
GO
