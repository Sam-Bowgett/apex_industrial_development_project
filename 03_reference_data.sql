-- =========================================================
-- Section 2: Reference Data
-- Calendar and Targets
-- =========================================================

--- Insert Calendar (2021-01-01 to 2025-12-31) ---

INSERT INTO calendar (
    date,
    year,
    quarter,
    month,
    month_name,
    week,
    day,
    financial_year
)
WITH calendar_dates AS (
    SELECT
        generate_series(
            DATE '2021-01-01',
            DATE '2025-12-31',
            INTERVAL '1 day'
        )::DATE AS calendar_date
)
SELECT
    calendar_date,
    EXTRACT(YEAR FROM calendar_date) AS year,
    EXTRACT(QUARTER FROM calendar_date) AS quarter,
    EXTRACT(MONTH FROM calendar_date) AS month,
    TO_CHAR(calendar_date, 'Month') AS month_name,
    EXTRACT(WEEK FROM calendar_date) AS week,
    EXTRACT(DAY FROM calendar_date) AS day,
    CASE
        WHEN EXTRACT(MONTH FROM calendar_date) >= 7
            THEN 'FY' || (EXTRACT(YEAR FROM calendar_date) + 1)::INT
        ELSE
            'FY' || EXTRACT(YEAR FROM calendar_date)::INT
    END AS financial_year
FROM calendar_dates;

--- Insert Targets (one row per salesperson per month) ---
-- NOTE: this is re-run in 06_target_rescale_fix.sql after annual_target values
-- were corrected to realistic figures. Kept here to preserve the original build order.

INSERT INTO targets (
    salesperson_id,
    year,
    month,
    monthly_target
)
WITH months AS (
    SELECT DISTINCT
        year,
        month
    FROM calendar
)
SELECT
    sp.salesperson_id,
    m.year,
    m.month,
    ROUND(sp.annual_target / 12, 2) AS monthly_target
FROM salespeople AS sp
CROSS JOIN months AS m;
