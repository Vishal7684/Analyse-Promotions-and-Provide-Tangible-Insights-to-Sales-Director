#Query1: High Value Products are on Heavy discounts

SELECT DISTINCT
    p.product_name AS product_name,
    f.promo_type AS promo_type,
    f.base_price AS base_price
FROM
    dim_products p
        JOIN
    fact_events f USING (product_code)
WHERE
    f.promo_type = 'BOGOF'
        AND f.base_price > 500
ORDER BY base_price DESC;

#Query 2: Store Count by City
SELECT 
    city, COUNT(*) AS store_count
FROM
    dim_stores
GROUP BY city
ORDER BY store_count DESC;

#Query 3: Revenue Before and After Promotion by Campaign
WITH cte AS
(
    SELECT
        c.campaign_name AS campaign_name,
        f.`quantity_sold(before_promo)` * f.base_price AS before_promo_revenue,
        f.`quantity_sold(after_promo)` * f.base_price AS after_promo_revenue
    FROM
        dim_campaigns c
    JOIN
        fact_events f
    USING (campaign_id)
)

SELECT 
    campaign_name,
    CONCAT(FORMAT(SUM(before_promo_revenue) / 1000000, 2), ' Millions') AS Revenue_before_promo,
    CONCAT(FORMAT(SUM(after_promo_revenue) / 1000000, 2), ' Millions') AS Revenue_after_promo
FROM 
    cte
GROUP BY 
    campaign_name
ORDER BY 
    Revenue_before_promo DESC, 
    Revenue_after_promo DESC;

# Query 4: Incremental Sold Unit Percentage by Campaign and Category
WITH cte AS
(
    SELECT
        c.campaign_name AS campaign_name,
        p.category AS category,
        SUM(f.`quantity_sold(before_promo)`) AS before_promo_quantity,
        SUM(f.`quantity_sold(after_promo)`) AS after_promo_quantity,
        ROUND(SUM(f.`quantity_sold(after_promo)`) - SUM(f.`quantity_sold(before_promo)`), 2) AS incremental_sold_unit,
        ROUND((SUM(f.`quantity_sold(after_promo)`) - SUM(f.`quantity_sold(before_promo)`)) / SUM(f.`quantity_sold(before_promo)`) * 100, 2) AS ISU_percentage
    FROM
        dim_campaigns c
    JOIN
        fact_events f
    USING (campaign_id)
    JOIN
        dim_products p
    USING(product_code)
    WHERE campaign_name = "Diwali"
    GROUP BY campaign_name, category
)

SELECT 
    category, 
    before_promo_quantity,
    after_promo_quantity, 
    incremental_sold_unit,
    ISU_percentage,
    RANK() OVER (ORDER BY ISU_percentage DESC) AS Rank_ISU_percentage
FROM 
    cte;

# Query 5: Top 5 Products with Incremental Revenue Percentage
SELECT 
    p.product_name AS Product_name,
    p.category AS category,
    SUM(f.`quantity_sold(before_promo)` * f.base_price) AS Revenue_before_promo,
    SUM(f.`quantity_sold(after_promo)` * f.base_price) AS Revenue_after_promo,
    SUM(f.`quantity_sold(after_promo)` * f.base_price) - SUM(f.`quantity_sold(before_promo)` * f.base_price) AS Increase_in_revenue,
    ROUND(((SUM(f.`quantity_sold(after_promo)` * f.base_price) - SUM(f.`quantity_sold(before_promo)` * f.base_price)) / SUM(f.`quantity_sold(before_promo)` * f.base_price)) * 100,
            2) AS Incremental_revenue_pct
FROM
    dim_products p
        JOIN
    fact_events f ON p.product_code = f.product_code
GROUP BY Product_name , category
ORDER BY Incremental_revenue_pct DESC
LIMIT 5;


