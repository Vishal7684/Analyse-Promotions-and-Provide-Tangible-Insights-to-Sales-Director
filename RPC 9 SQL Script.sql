-- Query 1: High-Value Products on Heavy Discounts
SELECT DISTINCT
    p.product_name AS product_name,
    f.promo_type AS promo_type,
    f.base_price AS base_price
FROM
    dim_products p
    JOIN fact_events f USING (product_code)
WHERE
    f.promo_type = 'BOGOF'
    AND f.base_price > 500
ORDER BY base_price DESC;

-- Query 2: Store Count by City
SELECT 
    city, COUNT(*) AS store_count
FROM
    dim_stores
GROUP BY city
ORDER BY store_count DESC;

-- Query 3: Revenue Before and After Promotion by Campaign
WITH cte AS (
    SELECT
        c.campaign_name AS campaign_name,
        f.`quantity_sold(before_promo)` * f.base_price AS before_promo_revenue,
        f.`quantity_sold(after_promo)` * f.base_price as after_promo_revenue,
        f.promo_type as promo_type
    FROM
        dim_campaigns c
    JOIN
        fact_events f
    USING (campaign_id)
)

SELECT 
    campaign_name,
    CONCAT(FORMAT(SUM(before_promo_revenue) / 1000000, 2), ' Millions') AS Revenue_before_promo,
    CONCAT(FORMAT(SUM(
        CASE 
            WHEN promo_type = "25% OFF" THEN after_promo_revenue * (1 - 0.25) 
            WHEN promo_type = "50% OFF" THEN after_promo_revenue * (1 - 0.50)
            WHEN promo_type = "33% OFF" THEN after_promo_revenue * (1 - 0.33) 
            WHEN promo_type = "500 OFF" THEN after_promo_revenue - 500 
            ELSE after_promo_revenue
        END
    ) / 1000000, 2), ' Millions') AS Revenue_after_promo
FROM 
    cte
GROUP BY 
    campaign_name
ORDER BY 
    Revenue_before_promo DESC, 
    Revenue_after_promo DESC;

-- Query 4: Incremental Sold Unit Percentage by Campaign and Category
WITH cte AS (
    SELECT
        c.campaign_name AS campaign_name,
        p.category AS category,
        SUM(f.`quantity_sold(before_promo)`) AS Quantity_before_promo,
        SUM(f.`quantity_sold(after_promo)`) AS Quantity_after_promo,
        f.promo_type AS promo_type
    FROM
        dim_products p
        JOIN fact_events f USING (product_code)
        JOIN dim_campaigns c USING (campaign_id)
    GROUP BY
        category, campaign_name, promo_type
),

cte2 AS (
    SELECT
        category,
        Quantity_before_promo,
        CASE WHEN promo_type = 'BOGOF' THEN Quantity_after_promo * 2 ELSE Quantity_after_promo END AS Quantity_after_promo
    FROM
        cte
    WHERE
        campaign_name = 'Diwali'
)

SELECT
    category,
    Quantity_before_promo,
    Quantity_after_promo,
	CONCAT(ROUND((Quantity_after_promo - Quantity_before_promo) / Quantity_before_promo * 100, 2), '%') AS ISU_percentage,
    RANK() OVER (ORDER BY (Quantity_after_promo - Quantity_before_promo) / Quantity_before_promo * 100 DESC) AS rankings
FROM
    cte2;

-- Query 5: Top 5 Products with Incremental Revenue Percentage
WITH Revenue AS (
    SELECT 
        p.product_name AS Product_name,
        p.category AS category,
        SUM(f.`quantity_sold(before_promo)`) * f.base_price AS Revenue_before_promo,
        SUM(
            CASE 
                WHEN promo_type = '25% OFF' THEN f.`quantity_sold(after_promo)` * (1 - 0.25) * f.base_price
                WHEN promo_type = '50% OFF' THEN f.`quantity_sold(after_promo)` * (1 - 0.50) * f.base_price
                WHEN promo_type = '33% OFF' THEN f.`quantity_sold(after_promo)` * (1 - 0.33) * f.base_price
                WHEN promo_type = '500 OFF' THEN (f.`quantity_sold(after_promo)` - 500) * f.base_price
                WHEN promo_type = 'BOGOF' THEN f.`quantity_sold(after_promo)` * f.base_price
                ELSE f.`quantity_sold(after_promo)` * f.base_price
            END
        ) AS Revenue_after_promo
    FROM
        dim_products p
        JOIN
        fact_events f ON p.product_code = f.product_code
    GROUP BY Product_name, category, f.base_price
)

SELECT 
    Product_name,
    category,
    Revenue_before_promo,
    Revenue_after_promo,
    CONCAT(ROUND((Revenue_after_promo - Revenue_before_promo) / Revenue_before_promo * 100, 2), '%') as IR
FROM Revenue
ORDER BY IR DESC
LIMIT 5;
