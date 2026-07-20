-- =========================================================
-- Section 5: Views
-- Pre-aggregated views serving as a clean interface between
-- the database and Power BI (Section 6), so the BI layer pulls
-- ready-made tables instead of re-running joins from scratch.
-- =========================================================

CREATE VIEW vw_revenue_by_month AS
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
SELECT * FROM monthly_revenue;


CREATE VIEW vw_revenue_by_state AS
SELECT
    cu.state,
    SUM(s.revenue) AS total_revenue,
    SUM(s.profit) AS total_profit,
    ROUND(100.0 * SUM(s.profit) / NULLIF(SUM(s.revenue), 0), 2) AS margin_pct,
    COUNT(s.sale_id) AS sales_count
FROM sales AS s
INNER JOIN customers AS cu
    ON cu.customer_id = s.customer_id
GROUP BY cu.state;


CREATE VIEW vw_revenue_by_product AS
SELECT
    p.product_id,
    p.product_name,
    SUM(s.revenue) AS total_revenue,
    SUM(s.profit) AS total_profit,
    COUNT(s.sale_id) AS sales_count,
    ROUND(AVG(s.revenue), 2) AS avg_revenue,
    ROUND(AVG(s.profit), 2) AS avg_profit,
    CASE
        WHEN AVG(s.profit) >= 150000 THEN 'High'
        WHEN AVG(s.profit) >= 50000 THEN 'Medium'
        ELSE 'Low'
    END AS profit_tier
FROM products AS p
INNER JOIN sales AS s
    ON p.product_id = s.product_id
GROUP BY
    p.product_id,
    p.product_name;


CREATE VIEW vw_salesperson_performance AS
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
    sp.hire_date;


CREATE VIEW vw_actual_vs_target AS
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
    AND ma.month = t.month;


CREATE VIEW vw_top_customers AS
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
    cu.state;


CREATE VIEW vw_pipeline_by_stage AS
SELECT
    stage,
    COUNT(opportunity_id) AS num_deals,
    SUM(expected_revenue) AS total_expected_revenue,
    ROUND(SUM(expected_revenue * probability / 100.0), 2) AS weighted_pipeline_value
FROM pipeline
GROUP BY stage;


CREATE VIEW vw_win_rate_by_salesperson AS
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
    sp.last_name;


CREATE VIEW vw_underperforming_states AS
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
FROM state_revenue;


CREATE VIEW vw_target_miss_rate AS
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
    sp.last_name;
