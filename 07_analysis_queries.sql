-- =========================================================
-- Section 5: SQL Business Analysis Queries
-- =========================================================

-- 1. Total revenue, total profit, margin %
-- "What's our overall commercial performance?"
SELECT
    SUM(revenue) AS total_revenue,
    SUM(profit) AS total_profit,
    ROUND(100.0 * SUM(profit) / NULLIF(SUM(revenue), 0), 2) AS margin_pct
FROM sales;


-- 2. Revenue by month
-- "How has our revenue trended month by month? Are there any months
--  that stand out as unusually strong or weak?"
WITH monthly_revenue AS (
    SELECT
        c.year,
        c.month,
        c.month_name,
        SUM(s.revenue) AS total_revenue
    FROM calendar AS c
    INNER JOIN sales AS s
        ON c.date = s.sale_date
    GROUP BY
        c.year,
        c.month,
        c.month_name
)
SELECT
    year,
    month_name,
    total_revenue
FROM monthly_revenue
ORDER BY
    year,
    month;


-- 3. Revenue by state
-- "Which states are generating the most revenue and profit for us?
--  Are any states underperforming relative to the others?"
SELECT
    cu.state,
    SUM(s.revenue) AS total_revenue,
    SUM(s.profit) AS total_profit,
    ROUND(100.0 * SUM(s.profit) / NULLIF(SUM(s.revenue), 0), 2) AS margin_pct,
    COUNT(s.sale_id) AS sales_count
FROM sales AS s
INNER JOIN customers AS cu
    ON cu.customer_id = s.customer_id
GROUP BY cu.state
ORDER BY total_revenue DESC;


-- 4. Revenue by product
-- "Which products and categories are driving the most revenue and
--  profit? Is there a product that sells a lot but barely makes
--  money, or one that sells rarely but is highly profitable per sale?"
WITH product_summary AS (
    SELECT
        p.product_id,
        p.product_name,
        SUM(s.revenue) AS total_revenue,
        SUM(s.profit) AS total_profit,
        COUNT(s.sale_id) AS sales_count,
        ROUND(AVG(s.revenue), 2) AS avg_revenue,
        ROUND(AVG(s.profit), 2) AS avg_profit
    FROM products AS p
    INNER JOIN sales AS s
        ON p.product_id = s.product_id
    GROUP BY
        p.product_id,
        p.product_name
)
SELECT
    product_id,
    product_name,
    total_revenue,
    total_profit,
    sales_count,
    avg_revenue,
    avg_profit,
    CASE
        WHEN avg_profit >= 150000 THEN 'High'
        WHEN avg_profit >= 50000 THEN 'Medium'
        ELSE 'Low'
    END AS profit_tier
FROM product_summary
ORDER BY total_revenue DESC;


-- 5. Salesperson performance
-- "Who are our top-performing salespeople by revenue and profit?
--  What's the average deal size per rep?"
WITH salesperson_summary AS (
    SELECT
        sp.salesperson_id,
        INITCAP(sp.first_name || ' ' || sp.last_name) AS full_name,
        sp.hire_date,
        SUM(s.revenue) AS total_revenue,
        SUM(s.profit) AS total_profit,
        ROUND(AVG(s.revenue), 2) AS avg_deal_size,
        COUNT(s.sale_id) AS sales_count
    FROM salespeople AS sp
    INNER JOIN sales AS s
        ON sp.salesperson_id = s.salesperson_id
    GROUP BY
        sp.salesperson_id,
        sp.hire_date
)
SELECT
    salesperson_id,
    full_name,
    hire_date,
    total_revenue,
    total_profit,
    avg_deal_size,
    sales_count
FROM salesperson_summary
ORDER BY total_revenue DESC;


-- 6. Actual vs target
-- "For each salesperson, each month - are they hitting their sales
--  target? By how much are they over or under?"
WITH monthly_actuals AS (
    SELECT
        salesperson_id,
        EXTRACT(YEAR FROM sale_date) AS year,
        EXTRACT(MONTH FROM sale_date) AS month,
        SUM(revenue) AS actual_revenue
    FROM sales
    GROUP BY
        salesperson_id,
        EXTRACT(YEAR FROM sale_date),
        EXTRACT(MONTH FROM sale_date)
)
SELECT
    t.salesperson_id,
    sp.first_name || ' ' || sp.last_name AS full_name,
    t.year,
    t.month,
    t.monthly_target,
    COALESCE(ma.actual_revenue, 0) AS actual_revenue,
    COALESCE(ma.actual_revenue, 0) - t.monthly_target AS variance,
    ROUND(100.0 * COALESCE(ma.actual_revenue, 0) / NULLIF(t.monthly_target, 0), 1) AS pct_of_target
FROM targets AS t
INNER JOIN salespeople AS sp
    ON sp.salesperson_id = t.salesperson_id
LEFT JOIN monthly_actuals AS ma
    ON ma.salesperson_id = t.salesperson_id
    AND ma.year = t.year
    AND ma.month = t.month
ORDER BY
    t.salesperson_id,
    t.year,
    t.month;


-- 7. Top customers
-- "Who are our 20 biggest customers by revenue? What industries and
--  states do they come from?"
SELECT
    cu.customer_id,
    cu.company_name,
    cu.industry,
    cu.state,
    SUM(s.revenue) AS total_revenue,
    SUM(s.profit) AS total_profit,
    COUNT(s.sale_id) AS num_purchases
FROM customers AS cu
INNER JOIN sales AS s
    ON s.customer_id = cu.customer_id
GROUP BY
    cu.customer_id,
    cu.company_name,
    cu.industry,
    cu.state
ORDER BY total_revenue DESC
LIMIT 20;


-- 8. Pipeline value
-- "How much potential revenue is sitting in our pipeline right now,
--  broken down by stage? If we apply the probability of each deal
--  closing, what's the pipeline actually worth today (weighted value)?"
SELECT
    stage,
    COUNT(opportunity_id) AS num_deals,
    SUM(expected_revenue) AS total_expected_revenue,
    ROUND(SUM(expected_revenue * probability / 100.0), 2) AS weighted_pipeline_value
FROM pipeline
GROUP BY stage
ORDER BY
    CASE stage
        WHEN 'Prospecting'   THEN 1
        WHEN 'Qualification' THEN 2
        WHEN 'Proposal'      THEN 3
        WHEN 'Negotiation'   THEN 4
        WHEN 'Closed Won'    THEN 5
        WHEN 'Closed Lost'   THEN 6
    END;


-- 9. Win-rate analysis
-- "Of all the deals we've closed (won or lost), what percentage do we
--  actually win? Does win rate vary a lot by salesperson?"

-- Overall win rate
SELECT
    COUNT(opportunity_id) FILTER (WHERE stage = 'Closed Won') AS deals_won,
    COUNT(opportunity_id) FILTER (WHERE stage = 'Closed Lost') AS deals_lost,
    COUNT(opportunity_id) FILTER (WHERE stage IN ('Closed Won', 'Closed Lost')) AS total_closed,
    ROUND(
        100.0 * COUNT(opportunity_id) FILTER (WHERE stage = 'Closed Won')
        / NULLIF(COUNT(opportunity_id) FILTER (WHERE stage IN ('Closed Won', 'Closed Lost')), 0),
        1
    ) AS win_rate_pct
FROM pipeline;

-- Win rate by salesperson
SELECT
    sp.salesperson_id,
    sp.first_name || ' ' || sp.last_name AS full_name,
    COUNT(pl.opportunity_id) FILTER (WHERE pl.stage = 'Closed Won') AS deals_won,
    COUNT(pl.opportunity_id) FILTER (WHERE pl.stage IN ('Closed Won', 'Closed Lost')) AS total_closed,
    ROUND(
        100.0 * COUNT(pl.opportunity_id) FILTER (WHERE pl.stage = 'Closed Won')
        / NULLIF(COUNT(pl.opportunity_id) FILTER (WHERE pl.stage IN ('Closed Won', 'Closed Lost')), 0),
        1
    ) AS win_rate_pct
FROM salespeople AS sp
INNER JOIN pipeline AS pl
    ON pl.salesperson_id = sp.salesperson_id
GROUP BY
    sp.salesperson_id,
    sp.first_name,
    sp.last_name
ORDER BY win_rate_pct DESC;


-- 10. Underperforming areas
-- "Which states are performing below the company average? Which
--  salespeople are missing their monthly target most often?"

-- States below company average revenue
WITH state_revenue AS (
    SELECT
        cu.state,
        SUM(s.revenue) AS total_revenue
    FROM customers AS cu
    INNER JOIN sales AS s
        ON s.customer_id = cu.customer_id
    GROUP BY cu.state
)
SELECT
    state,
    total_revenue,
    ROUND(AVG(total_revenue) OVER (), 2) AS company_avg_revenue,
    ROUND(total_revenue - AVG(total_revenue) OVER (), 2) AS variance_from_avg
FROM state_revenue
ORDER BY total_revenue ASC;

-- Salespeople missing target most often (restricted to 2022+ since
-- sales data doesn't cover 2021, which is in the calendar/targets range)
WITH monthly_actuals AS (
    SELECT
        salesperson_id,
        EXTRACT(YEAR FROM sale_date) AS year,
        EXTRACT(MONTH FROM sale_date) AS month,
        SUM(revenue) AS actual_revenue
    FROM sales
    GROUP BY
        salesperson_id,
        EXTRACT(YEAR FROM sale_date),
        EXTRACT(MONTH FROM sale_date)
),
target_performance AS (
    SELECT
        t.salesperson_id,
        t.year,
        t.month,
        t.monthly_target,
        COALESCE(ma.actual_revenue, 0) AS actual_revenue
    FROM targets AS t
    LEFT JOIN monthly_actuals AS ma
        ON ma.salesperson_id = t.salesperson_id
        AND ma.year = t.year
        AND ma.month = t.month
    WHERE t.year >= 2022
)
SELECT
    sp.salesperson_id,
    sp.first_name || ' ' || sp.last_name AS full_name,
    COUNT(tp.month) FILTER (WHERE tp.actual_revenue < tp.monthly_target) AS months_missed,
    COUNT(tp.month) AS total_months,
    ROUND(
        100.0 * COUNT(tp.month) FILTER (WHERE tp.actual_revenue < tp.monthly_target)
        / COUNT(tp.month),
        1
    ) AS pct_months_missed
FROM salespeople AS sp
INNER JOIN target_performance AS tp
    ON tp.salesperson_id = sp.salesperson_id
GROUP BY
    sp.salesperson_id,
    sp.first_name,
    sp.last_name
ORDER BY pct_months_missed DESC;
