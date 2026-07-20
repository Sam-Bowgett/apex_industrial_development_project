-- =========================================================
-- Section 4: Pipeline Opportunity Data
-- Final corrected version (800 rows)
-- Same bug fixes applied as 04_sales_data.sql (correlated random
-- selection + LEFT JOIN LATERAL for salesperson state matching).
-- =========================================================

INSERT INTO pipeline (
    customer_id,
    salesperson_id,
    product_id,
    stage,
    probability,
    expected_close_date,
    expected_revenue
)
WITH pipeline_seed AS (
    SELECT
        gs AS opp_number,
        random() AS customer_rnd,
        random() AS product_rnd,
        random() AS salesperson_rnd,
        random() AS stage_rnd,
        random() AS date_rnd,
        random() AS quantity_rnd
    FROM generate_series(1, 800) AS gs
)
SELECT
    cm.customer_id,
    sp.salesperson_id,
    p.product_id,
    st.stage,
    st.probability,
    dt.expected_close_date,
    ROUND(p.list_price * qt.quantity, 2) AS expected_revenue
FROM pipeline_seed
CROSS JOIN LATERAL (
    SELECT customer_id, state
    FROM (
        SELECT
            customer_id,
            state,
            ROW_NUMBER() OVER () AS rn,
            COUNT(*) OVER () AS cnt
        FROM customers
    ) x
    WHERE rn = 1 + FLOOR(pipeline_seed.customer_rnd * cnt)
) AS cm
CROSS JOIN LATERAL (
    SELECT
        product_id,
        list_price
    FROM products
    WHERE category = CASE
        WHEN pipeline_seed.product_rnd < 0.32 THEN 'Earthmoving'
        WHEN pipeline_seed.product_rnd < 0.57 THEN 'Material Handling'
        WHEN pipeline_seed.product_rnd < 0.75 THEN 'Power Equipment'
        WHEN pipeline_seed.product_rnd < 0.90 THEN 'Site Equipment'
        ELSE 'Compressors'
    END
    ORDER BY random()
    LIMIT 1
) AS p
LEFT JOIN LATERAL (
    SELECT salesperson_id
    FROM (
        SELECT
            salesperson_id,
            ROW_NUMBER() OVER () AS rn,
            COUNT(*) OVER () AS cnt
        FROM salespeople
        WHERE state = cm.state
    ) y
    WHERE rn = 1 + FLOOR(pipeline_seed.salesperson_rnd * cnt)
) AS sp_matched ON true
CROSS JOIN LATERAL (
    SELECT
        COALESCE(sp_matched.salesperson_id, sp_fallback.salesperson_id) AS salesperson_id
    FROM (
        SELECT salesperson_id
        FROM (
            SELECT
                salesperson_id,
                ROW_NUMBER() OVER () AS rn,
                COUNT(*) OVER () AS cnt
            FROM salespeople
        ) z
        WHERE rn = 1 + FLOOR(pipeline_seed.salesperson_rnd * cnt)
    ) AS sp_fallback
) AS sp
-- Stage and probability are derived from the SAME random value (stage_rnd)
-- so they can never fall out of sync with each other.
CROSS JOIN LATERAL (
    SELECT
        CASE
            WHEN pipeline_seed.stage_rnd < 0.30 THEN 'Prospecting'
            WHEN pipeline_seed.stage_rnd < 0.55 THEN 'Qualification'
            WHEN pipeline_seed.stage_rnd < 0.75 THEN 'Proposal'
            WHEN pipeline_seed.stage_rnd < 0.90 THEN 'Negotiation'
            WHEN pipeline_seed.stage_rnd < 0.96 THEN 'Closed Won'
            ELSE 'Closed Lost'
        END AS stage,
        CASE
            WHEN pipeline_seed.stage_rnd < 0.30 THEN 10
            WHEN pipeline_seed.stage_rnd < 0.55 THEN 25
            WHEN pipeline_seed.stage_rnd < 0.75 THEN 50
            WHEN pipeline_seed.stage_rnd < 0.90 THEN 75
            WHEN pipeline_seed.stage_rnd < 0.96 THEN 100
            ELSE 0
        END AS probability
) AS st
-- Close dates constrained to the last 6 months of the calendar range
-- so every deal stays joinable to the existing calendar table.
CROSS JOIN LATERAL (
    SELECT
        (DATE '2025-07-01'
            + (pipeline_seed.date_rnd * (DATE '2025-12-31' - DATE '2025-07-01'))::int
        ) AS expected_close_date
) AS dt
CROSS JOIN LATERAL (
    SELECT
        (1 + FLOOR(pipeline_seed.quantity_rnd * 10))::int AS quantity
) AS qt;
