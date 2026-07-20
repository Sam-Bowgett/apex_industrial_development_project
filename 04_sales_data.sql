-- =========================================================
-- Sprint 3: Sales Transaction Data
-- Final corrected version (10,000 rows)
--
-- Bug history (see README for full write-up):
-- 1) Initial version picked customer/salesperson via an UNCORRELATED
--    "ORDER BY random() LIMIT 1" inside CROSS JOIN LATERAL. Postgres
--    evaluated it once and reused the result for every row, collapsing
--    every sale onto a single customer/salesperson.
--    FIX: use ROW_NUMBER()/COUNT() windows and select the row whose
--    rn matches a per-row random offset (correlated to sales_seed).
-- 2) After fixing (1), the salesperson-state-match CROSS JOIN LATERAL
--    silently dropped any customer whose state had no matching
--    salesperson (TAS/NT/ACT), because CROSS JOIN LATERAL behaves like
--    an inner join - zero matches = row disappears before the
--    COALESCE fallback ever runs.
--    FIX: change the matched-salesperson block to LEFT JOIN LATERAL
--    ... ON true, so it returns NULL instead of eliminating the row,
--    letting the COALESCE fallback catch it.
-- =========================================================

INSERT INTO sales (
    customer_id,
    salesperson_id,
    product_id,
    sale_date,
    quantity,
    discount_percent,
    unit_price,
    revenue,
    cost,
    profit
)
WITH sales_seed AS (
    SELECT
        gs AS sale_number,
        random() AS customer_rnd,
        random() AS product_rnd,
        random() AS salesperson_rnd,
        random() AS date_rnd,
        random() AS discount_rnd,
        random() AS quantity_rnd
    FROM generate_series(1, 10000) AS gs
)
SELECT
    cm.customer_id,
    sp.salesperson_id,
    p.product_id,
    dt.sale_date,
    qt.quantity,
    dc.discount_percent,
    ROUND(p.list_price * (1 - dc.discount_percent / 100.0), 2) AS unit_price,
    ROUND(p.list_price * (1 - dc.discount_percent / 100.0) * qt.quantity, 2) AS revenue,
    ROUND(p.standard_cost * qt.quantity, 2) AS cost,
    ROUND(
        (p.list_price * (1 - dc.discount_percent / 100.0) * qt.quantity)
        - (p.standard_cost * qt.quantity),
        2
    ) AS profit
FROM sales_seed
-- Weighted random customer (correlated via customer_rnd)
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
    WHERE rn = 1 + FLOOR(sales_seed.customer_rnd * cnt)
) AS cm
-- Weighted product category (32/25/18/15/10 split), correlated via product_rnd
CROSS JOIN LATERAL (
    SELECT
        product_id,
        category,
        standard_cost,
        list_price
    FROM products
    WHERE category = CASE
        WHEN sales_seed.product_rnd < 0.32 THEN 'Earthmoving'
        WHEN sales_seed.product_rnd < 0.57 THEN 'Material Handling'
        WHEN sales_seed.product_rnd < 0.75 THEN 'Power Equipment'
        WHEN sales_seed.product_rnd < 0.90 THEN 'Site Equipment'
        ELSE 'Compressors'
    END
    ORDER BY random()
    LIMIT 1
) AS p
-- Salesperson matched to customer's state (LEFT JOIN LATERAL so unmatched states
-- don't drop the row - falls through to the fallback block below)
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
    WHERE rn = 1 + FLOOR(sales_seed.salesperson_rnd * cnt)
) AS sp_matched ON true
-- Fallback: random salesperson from anywhere, used only if sp_matched is NULL
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
        WHERE rn = 1 + FLOOR(sales_seed.salesperson_rnd * cnt)
    ) AS sp_fallback
) AS sp
-- Sale date, spread evenly across 2022-01-01 to 2025-12-31 (inside the calendar range)
CROSS JOIN LATERAL (
    SELECT
        (DATE '2022-01-01'
            + (sales_seed.date_rnd * (DATE '2025-12-31' - DATE '2022-01-01'))::int
        ) AS sale_date
) AS dt
-- Weighted discount tiers: 50% none, 30% 5%, 15% 10%, 5% 15%
CROSS JOIN LATERAL (
    SELECT
        CASE
            WHEN sales_seed.discount_rnd < 0.50 THEN 0
            WHEN sales_seed.discount_rnd < 0.80 THEN 5
            WHEN sales_seed.discount_rnd < 0.95 THEN 10
            ELSE 15
        END AS discount_percent
) AS dc
-- Quantity: 1-10 units
CROSS JOIN LATERAL (
    SELECT
        (1 + FLOOR(sales_seed.quantity_rnd * 10))::int AS quantity
) AS qt;
