-- =========================================================
-- Sprint 5: Target Rescale Fix
--
-- Bug: annual_target values entered in Sprint 1 were set independently
-- of the product pricing / volume used later to generate sales data.
-- Result: every salesperson's actual monthly revenue was ~25-35x their
-- monthly target, so every "actual vs target" and "underperforming"
-- query showed 0% of months missed for every rep - not a query bug,
-- a data-scale mismatch.
--
-- Fix: recalculate annual_target as 90% of each salesperson's actual
-- average annual revenue (based on 4 years of generated sales data),
-- then rebuild the targets table from the corrected values.
--
-- Also required widening salespeople.annual_target and
-- targets.monthly_target from DECIMAL(10,2) to DECIMAL(14,2), since
-- realistic targets (hundreds of millions) exceeded the original
-- column's ~100 million ceiling.
-- =========================================================

ALTER TABLE salespeople
ALTER COLUMN annual_target TYPE DECIMAL(14,2);

ALTER TABLE targets
ALTER COLUMN monthly_target TYPE DECIMAL(14,2);

UPDATE salespeople sp
SET annual_target = realistic.new_target
FROM (
    SELECT
        s.salesperson_id,
        ROUND((SUM(s.revenue) / 4.0) * 0.90, 2) AS new_target  -- 4 years of data, 90% of actual avg annual revenue
    FROM sales AS s
    GROUP BY s.salesperson_id
) AS realistic
WHERE sp.salesperson_id = realistic.salesperson_id;

TRUNCATE TABLE targets;

INSERT INTO targets (
    salesperson_id,
    year,
    month,
    monthly_target
)
WITH months AS (
    SELECT DISTINCT year, month
    FROM calendar
)
SELECT
    sp.salesperson_id,
    m.year,
    m.month,
    ROUND(sp.annual_target / 12, 2) AS monthly_target
FROM salespeople AS sp
CROSS JOIN months AS m;

-- Validation: monthly_target should now be roughly in the same
-- ballpark as avg_actual_monthly_revenue for every rep, not 25-35x apart.
SELECT
    sp.salesperson_id,
    sp.annual_target,
    ROUND(sp.annual_target / 12, 2) AS monthly_target,
    SUM(s.revenue) / 48.0 AS avg_actual_monthly_revenue
FROM salespeople AS sp
INNER JOIN sales AS s
    ON s.salesperson_id = sp.salesperson_id
GROUP BY sp.salesperson_id, sp.annual_target
ORDER BY sp.salesperson_id;
