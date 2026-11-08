-- DESCRIPTION: RFM Customer Segmentation, Value Contribution & Marketing Strategy in T-SQL

USE OlistEcommerce;
GO

CREATE OR ALTER VIEW dbo.vw_customer_rfm_segments AS
WITH Base_Customer_Data AS (
    SELECT 
        c.customer_unique_id,
        MIN(o.order_purchase_timestamp) AS first_order_date,
        MAX(o.order_purchase_timestamp) AS last_order_date,
        -- Reference anchor date: day after the latest recorded delivered order in Olist dataset
        DATEDIFF(day, MAX(o.order_purchase_timestamp), '2018-09-03') AS recency_days,
        DATEDIFF(day, MIN(o.order_purchase_timestamp), MAX(o.order_purchase_timestamp)) AS customer_tenure_days,
        COUNT(DISTINCT o.order_id) AS frequency_orders,
        COUNT(oi.order_item_id) AS total_items_bought,
        SUM(oi.price) AS total_item_spend,
        SUM(oi.freight_value) AS total_freight_paid,
        SUM(oi.price + oi.freight_value) AS monetary_value
    FROM dbo.customers c
    INNER JOIN dbo.orders o ON c.customer_id = o.customer_id
    INNER JOIN dbo.order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
RFM_Scoring AS (
    SELECT 
        customer_unique_id,
        first_order_date,
        last_order_date,
        recency_days,
        customer_tenure_days,
        frequency_orders,
        total_items_bought,
        monetary_value,
        total_freight_paid,
        ROUND(monetary_value / frequency_orders, 2) AS customer_aov,
        -- Recency Quintile: 5 = Most Recent (lowest days), 1 = Oldest
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        -- Frequency Score: Tiered classification tailored for marketplace repeat dynamics
        CASE 
            WHEN frequency_orders >= 3 THEN 5
            WHEN frequency_orders = 2 THEN 4
            ELSE 1 
        END AS f_score,
        -- Monetary Quintile: 5 = Highest Spender, 1 = Lowest
        NTILE(5) OVER (ORDER BY monetary_value ASC) AS m_score
    FROM Base_Customer_Data
),
RFM_Segmentation AS (
    SELECT 
        *,
        CONCAT(r_score, f_score, m_score) AS rfm_cell,
        CASE 
            WHEN f_score >= 4 AND r_score >= 3 THEN 1
            WHEN r_score >= 4 AND f_score = 1 AND m_score >= 4 THEN 2
            WHEN r_score >= 3 AND f_score = 1 AND m_score >= 3 THEN 3
            WHEN r_score >= 3 AND f_score = 1 AND m_score < 3 THEN 4
            WHEN (r_score <= 2 AND m_score >= 4) OR (f_score >= 4 AND r_score <= 2) THEN 5
            ELSE 6
        END AS segment_sort_order,
        CASE 
            WHEN f_score >= 4 AND r_score >= 3 THEN '1. Champions & Loyal Repeaters'
            WHEN r_score >= 4 AND f_score = 1 AND m_score >= 4 THEN '2. Promising High-Spenders'
            WHEN r_score >= 3 AND f_score = 1 AND m_score >= 3 THEN '3. Potential Loyalists'
            WHEN r_score >= 3 AND f_score = 1 AND m_score < 3 THEN '4. Recent Low-Spenders'
            WHEN (r_score <= 2 AND m_score >= 4) OR (f_score >= 4 AND r_score <= 2) THEN '5. At-Risk High-Value'
            ELSE '6. Lost / Dormant'
        END AS customer_segment,
        CASE 
            WHEN f_score >= 4 AND r_score >= 3 THEN 'VIP tier rewards, early access to sales, referral bonus program'
            WHEN r_score >= 4 AND f_score = 1 AND m_score >= 4 THEN 'Priority 2nd-order voucher within 30 days, premium cross-sell'
            WHEN r_score >= 3 AND f_score = 1 AND m_score >= 3 THEN 'Personalized category recommendations & bundle discounts'
            WHEN r_score >= 3 AND f_score = 1 AND m_score < 3 THEN 'Minimum basket size threshold coupon to lift AOV'
            WHEN (r_score <= 2 AND m_score >= 4) OR (f_score >= 4 AND r_score <= 2) THEN 'High-priority win-back campaign with time-limited 15% discount'
            ELSE 'Exclude from paid retargeting ads; low-cost automated email only'
        END AS strategic_recommendation
    FROM RFM_Scoring
)
SELECT * FROM RFM_Segmentation;
GO

-- SEGMENT PROFILE & ECONOMIC VALUE SUMMARY
SELECT 
    segment_sort_order,
    customer_segment,
    COUNT(*) AS total_customers,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5, 2)) AS customer_share_pct,
    ROUND(SUM(monetary_value), 2) AS total_revenue,
    CAST(SUM(monetary_value) * 100.0 / SUM(SUM(monetary_value)) OVER() AS DECIMAL(5, 2)) AS revenue_share_pct,
    ROUND(AVG(CAST(recency_days AS FLOAT)), 1) AS avg_recency_days,
    ROUND(AVG(CAST(frequency_orders AS FLOAT)), 2) AS avg_frequency,
    ROUND(AVG(monetary_value), 2) AS avg_customer_ltv,
    ROUND(AVG(customer_aov), 2) AS avg_order_value,
    MAX(strategic_recommendation) AS action_strategy
FROM dbo.vw_customer_rfm_segments
GROUP BY segment_sort_order, customer_segment
ORDER BY segment_sort_order;
GO
