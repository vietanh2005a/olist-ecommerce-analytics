-- DESCRIPTION: Comprehensive Fulfillment Lead Times, Logistics SLA & Review Ratings in T-SQL

USE OlistEcommerce;
GO

CREATE OR ALTER VIEW dbo.vw_logistics_sla_performance AS
WITH Order_Logistics_Base AS (
    SELECT 
        o.order_id,
        o.customer_id,
        c.customer_state,
        c.customer_city,
        o.order_purchase_timestamp,
        o.order_approved_at,
        o.order_delivered_carrier_date,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        
        -- Granular Stage Lead Times
        DATEDIFF(hour, o.order_purchase_timestamp, o.order_approved_at) AS payment_approval_hours,
        DATEDIFF(day, o.order_approved_at, o.order_delivered_carrier_date) AS carrier_dispatch_days,
        DATEDIFF(day, o.order_delivered_carrier_date, o.order_delivered_customer_date) AS transit_delivery_days,
        DATEDIFF(day, o.order_purchase_timestamp, o.order_delivered_customer_date) AS total_lead_time_days,
        DATEDIFF(day, o.order_purchase_timestamp, o.order_estimated_delivery_date) AS promised_sla_days,
        
        -- SLA Variance (Actual - Promised)
        DATEDIFF(day, o.order_estimated_delivery_date, o.order_delivered_customer_date) AS delay_days,
        
        CASE 
            WHEN DATEDIFF(day, o.order_estimated_delivery_date, o.order_delivered_customer_date) <= -3 THEN 1
            WHEN DATEDIFF(day, o.order_estimated_delivery_date, o.order_delivered_customer_date) BETWEEN -2 AND 0 THEN 2
            WHEN DATEDIFF(day, o.order_estimated_delivery_date, o.order_delivered_customer_date) BETWEEN 1 AND 3 THEN 3
            WHEN DATEDIFF(day, o.order_estimated_delivery_date, o.order_delivered_customer_date) BETWEEN 4 AND 7 THEN 4
            ELSE 5
        END AS sla_sort_order,

        CASE 
            WHEN DATEDIFF(day, o.order_estimated_delivery_date, o.order_delivered_customer_date) <= -3 THEN '1. Ahead of Schedule (> 3 Days Early)'
            WHEN DATEDIFF(day, o.order_estimated_delivery_date, o.order_delivered_customer_date) BETWEEN -2 AND 0 THEN '2. On-time (0 - 2 Days Early)'
            WHEN DATEDIFF(day, o.order_estimated_delivery_date, o.order_delivered_customer_date) BETWEEN 1 AND 3 THEN '3. Delayed 1 - 3 Days'
            WHEN DATEDIFF(day, o.order_estimated_delivery_date, o.order_delivered_customer_date) BETWEEN 4 AND 7 THEN '4. Delayed 4 - 7 Days'
            ELSE '5. Delayed > 7 Days (Critical)'
        END AS delivery_sla_status,
        
        -- Refined condition: Consistent with day-level SLA grouping
        CASE 
            WHEN DATEDIFF(day, o.order_estimated_delivery_date, o.order_delivered_customer_date) > 0 THEN 1 
            ELSE 0 
        END AS is_delayed_flag
    FROM dbo.orders o
    INNER JOIN dbo.customers c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_estimated_delivery_date IS NOT NULL
),
Orders_With_Reviews AS (
    SELECT 
        olb.*,
        r.review_score,
        CASE WHEN r.review_score = 1 THEN 1 ELSE 0 END AS is_1_star,
        CASE WHEN r.review_score = 5 THEN 1 ELSE 0 END AS is_5_star
    FROM Order_Logistics_Base olb
    LEFT JOIN dbo.order_reviews r ON olb.order_id = r.order_id
)
SELECT * FROM Orders_With_Reviews;
GO

-- 1. SLA PERFORMANCE VS. CUSTOMER SATISFACTION IMPACT
SELECT 
    sla_sort_order,
    delivery_sla_status,
    COUNT(DISTINCT order_id) AS total_orders,
    CAST(COUNT(DISTINCT order_id) * 100.0 / SUM(COUNT(DISTINCT order_id)) OVER() AS DECIMAL(5, 2)) AS order_share_pct,
    ROUND(AVG(CAST(total_lead_time_days AS FLOAT)), 1) AS avg_total_delivery_days,
    ROUND(AVG(CAST(delay_days AS FLOAT)), 1) AS avg_delay_days,
    ROUND(AVG(CAST(review_score AS FLOAT)), 2) AS avg_review_score,
    CAST(SUM(is_1_star) * 100.0 / COUNT(review_score) AS DECIMAL(5, 2)) AS one_star_rate_pct,
    CAST(SUM(is_5_star) * 100.0 / COUNT(review_score) AS DECIMAL(5, 2)) AS five_star_rate_pct
FROM dbo.vw_logistics_sla_performance
GROUP BY sla_sort_order, delivery_sla_status
ORDER BY sla_sort_order;
GO

-- 2. STATE-LEVEL BOTTLENECKS (Top 10 Destination States with Highest Delay Rates, min 300 orders)
SELECT TOP 10
    customer_state,
    COUNT(DISTINCT order_id) AS total_delivered_orders,
    ROUND(AVG(CAST(total_lead_time_days AS FLOAT)), 1) AS avg_delivery_days,
    ROUND(AVG(CAST(promised_sla_days AS FLOAT)), 1) AS avg_promised_sla_days,
    CAST(SUM(is_delayed_flag) * 100.0 / COUNT(*) AS DECIMAL(5, 2)) AS delay_rate_pct,
    ROUND(AVG(CAST(review_score AS FLOAT)), 2) AS avg_customer_rating,
    CAST(SUM(is_1_star) * 100.0 / COUNT(review_score) AS DECIMAL(5, 2)) AS one_star_pct
FROM dbo.vw_logistics_sla_performance
GROUP BY customer_state
HAVING COUNT(DISTINCT order_id) >= 300
ORDER BY delay_rate_pct DESC;
GO
