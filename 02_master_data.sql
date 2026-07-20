-- =========================================================
-- Section 1: Master Data
-- Products, Salespeople, Customer Master, Customers
-- =========================================================

--- Insert Products ---

INSERT INTO products (
    product_name,
    category,
    standard_cost,
    list_price
)
VALUES
    ('Excavator X200', 'Earthmoving', 180000.00, 245000.00),
    ('Wheel Loader L150', 'Earthmoving', 150000.00, 210000.00),
    ('Diesel Generator DG500', 'Power Equipment', 38000.00, 56000.00),
    ('Forklift F35', 'Material Handling', 24000.00, 39500.00),
    ('Air Compressor AC900', 'Compressors', 9500.00, 15500.00),
    ('Lighting Tower LT8', 'Site Equipment', 6800.00, 11500.00);

--- Insert Salespeople ---

INSERT INTO salespeople (
    first_name,
    last_name,
    state,
    region,
    manager,
    hire_date,
    annual_target
)
VALUES
    ('Sarah',   'Mitchell', 'NSW', 'East',  'Andrew Thompson', '2017-03-13', 6500000.00),
    ('James',   'Carter',   'VIC', 'South', 'Andrew Thompson', '2019-07-22', 5800000.00),
    ('Emily',   'Chen',     'QLD', 'North', 'Andrew Thompson', '2020-01-20', 6200000.00),
    ('Michael', 'Evans',    'WA',  'West',  'Andrew Thompson', '2018-10-15', 5500000.00),
    ('Daniel',  'Murphy',   'SA',  'South', 'Andrew Thompson', '2015-05-04', 4000000.00),
    ('Olivia',  'Taylor',   'NSW', 'East',  'Andrew Thompson', '2023-02-06', 5200000.00),
    ('Ethan',   'Brooks',   'QLD', 'North', 'Andrew Thompson', '2021-08-16', 5600000.00),
    ('Chloe',   'Wilson',   'VIC', 'South', 'Andrew Thompson', '2024-06-03', 4800000.00);

-- Note: these starting annual_target values were later found to be unrealistic relative to
-- actual generated sales volume and were recalculated in 06_target_rescale_fix.sql (Sprint 5).

--- Insert Generated Business Names (Customer Master) ---

INSERT INTO customer_master (company_name, industry)
VALUES
-- Mining
('Pilbara Mining Services', 'Mining'),
('Iron Ridge Resources', 'Mining'),
('Red Rock Mining', 'Mining'),
('Western Ore Solutions', 'Mining'),
('Frontier Minerals', 'Mining'),
('Outback Mining Group', 'Mining'),
('Northern Resources', 'Mining'),
('Titan Mining', 'Mining'),
('Summit Resources', 'Mining'),
('Horizon Mining', 'Mining'),
('Goldfields Resources', 'Mining'),
('Western Coal Services', 'Mining'),
('Iron Peak Mining', 'Mining'),
('Blue Rock Minerals', 'Mining'),
('MineralTech Australia', 'Mining'),

-- Construction
('Metro Civil Works', 'Construction'),
('Summit Infrastructure', 'Construction'),
('Urban Build Solutions', 'Construction'),
('Capital Construction', 'Construction'),
('Elite Contractors', 'Construction'),
('Horizon Projects', 'Construction'),
('Precision Civil', 'Construction'),
('Apex Infrastructure', 'Construction'),
('Titan Earthworks', 'Construction'),
('Premier Construction Group', 'Construction'),
('Australian Civil Solutions', 'Construction'),
('National Construction Services', 'Construction'),
('Eastern Infrastructure', 'Construction'),
('Core Civil Group', 'Construction'),
('NextGen Construction', 'Construction'),

-- Manufacturing
('Precision Manufacturing', 'Manufacturing'),
('Southern Industrial', 'Manufacturing'),
('National Engineering', 'Manufacturing'),
('Prime Fabrication', 'Manufacturing'),
('Titan Manufacturing', 'Manufacturing'),
('Australian Industrial Components', 'Manufacturing'),
('Metro Engineering', 'Manufacturing'),
('Capital Manufacturing', 'Manufacturing'),
('Summit Engineering', 'Manufacturing'),
('Elite Industrial', 'Manufacturing'),
('Advanced Fabrication', 'Manufacturing'),
('Apex Engineering', 'Manufacturing'),
('Industrial Solutions Australia', 'Manufacturing'),
('ProTech Manufacturing', 'Manufacturing'),
('Southern Steel Works', 'Manufacturing'),

-- Warehousing
('National Warehousing', 'Warehousing'),
('Metro Distribution', 'Warehousing'),
('Capital Storage', 'Warehousing'),
('Summit Logistics', 'Warehousing'),
('Frontier Warehousing', 'Warehousing'),
('Precision Distribution', 'Warehousing'),
('Elite Supply Chain', 'Warehousing'),
('Southern Logistics', 'Warehousing'),
('Central Warehousing', 'Warehousing'),
('Warehouse Connect', 'Warehousing'),
('Apex Distribution', 'Warehousing'),
('Storage Solutions Australia', 'Warehousing'),
('Logistics Plus', 'Warehousing'),
('Warehouse Direct', 'Warehousing'),
('National Distribution Services', 'Warehousing'),

-- Agriculture
('Greenfield Agriculture', 'Agriculture'),
('Riverland Farming', 'Agriculture'),
('Southern Ag Services', 'Agriculture'),
('Rural Equipment Group', 'Agriculture'),
('Harvest Solutions', 'Agriculture'),
('Premier Agriculture', 'Agriculture'),
('Western Farming', 'Agriculture'),
('AgriTech Australia', 'Agriculture'),
('Country Harvest', 'Agriculture'),
('Outback Agriculture', 'Agriculture'),
('FarmPro Services', 'Agriculture'),
('Agri Solutions', 'Agriculture'),
('Golden Fields', 'Agriculture'),
('Rural Industries', 'Agriculture'),
('Harvest Equipment', 'Agriculture'),

-- Transport
('National Freight', 'Transport'),
('Capital Logistics', 'Transport'),
('Metro Haulage', 'Transport'),
('Western Transport', 'Transport'),
('Southern Freight', 'Transport'),
('Frontier Logistics', 'Transport'),
('Prime Transport', 'Transport'),
('Interstate Freight Solutions', 'Transport'),
('Apex Logistics', 'Transport'),
('Express Haulage', 'Transport'),
('Highway Freight', 'Transport'),
('Cross Country Logistics', 'Transport'),
('Australian Bulk Transport', 'Transport'),
('NextGen Logistics', 'Transport'),
('FreightLink Australia', 'Transport');

--- Insert Customers (500 generated records, weighted state distribution) ---

INSERT INTO customers (
    company_name,
    industry,
    state,
    city,
    customer_size,
    created_date
)
WITH customer_seed AS (
    SELECT
        gs,
        random() AS state_rnd,
        random() AS size_rnd,
        random() AS date_rnd
    FROM generate_series(1, 500) gs
)
SELECT
    cm.company_name,
    cm.industry,
    CASE
        WHEN state_rnd < 0.28 THEN 'NSW'
        WHEN state_rnd < 0.52 THEN 'VIC'
        WHEN state_rnd < 0.72 THEN 'QLD'
        WHEN state_rnd < 0.86 THEN 'WA'
        WHEN state_rnd < 0.93 THEN 'SA'
        WHEN state_rnd < 0.96 THEN 'TAS'
        WHEN state_rnd < 0.98 THEN 'ACT'
        ELSE 'NT'
    END AS state,
    'City ' || gs AS city,
    CASE
        WHEN size_rnd < 0.40 THEN 'Small'
        WHEN size_rnd < 0.70 THEN 'Medium'
        WHEN size_rnd < 0.90 THEN 'Large'
        ELSE 'Enterprise'
    END AS customer_size,
    DATE '2021-01-01' + (date_rnd * 1460)::INT AS created_date
FROM customer_seed cs
CROSS JOIN LATERAL (
    SELECT company_name, industry
    FROM customer_master
    ORDER BY random()
    LIMIT 1
) cm;
