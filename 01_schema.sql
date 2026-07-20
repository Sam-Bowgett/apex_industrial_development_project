-- =========================================================
-- Sprint 1: Database Schema
-- Industrial Equipment Supplier - Sales & Pipeline Analytics
-- =========================================================

CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    company_name VARCHAR(100) NOT NULL,
    industry VARCHAR(50) NOT NULL,
    state VARCHAR(3) NOT NULL,
    city VARCHAR(50) NOT NULL,
    customer_size VARCHAR(20) NOT NULL,
    created_date DATE NOT NULL
);

CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL UNIQUE,
    category VARCHAR(50) NOT NULL,
    standard_cost DECIMAL(10,2) NOT NULL CHECK (standard_cost >= 0.00),
    list_price DECIMAL(10,2) NOT NULL CHECK (list_price >= 0.00)
);

CREATE TABLE salespeople (
    salesperson_id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    state VARCHAR(3) NOT NULL,
    region VARCHAR(50) NOT NULL,
    manager VARCHAR(100) NOT NULL,
    hire_date DATE NOT NULL,
    annual_target DECIMAL(14,2) NOT NULL CHECK (annual_target >= 0.00) -- widened from (10,2) after Sprint 5 target-scale fix
);

CREATE TABLE sales (
    sale_id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(customer_id),
    salesperson_id INT NOT NULL REFERENCES salespeople(salesperson_id),
    product_id INT NOT NULL REFERENCES products(product_id),
    sale_date DATE NOT NULL,
    quantity INT NOT NULL,
    discount_percent DECIMAL(5,2) DEFAULT 0,
    unit_price DECIMAL(12,2) NOT NULL,
    revenue DECIMAL(14,2) NOT NULL,
    cost DECIMAL(14,2) NOT NULL,
    profit DECIMAL(14,2) NOT NULL
);

CREATE TABLE pipeline (
    opportunity_id SERIAL PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(customer_id),
    salesperson_id INT NOT NULL REFERENCES salespeople(salesperson_id),
    product_id INT NOT NULL REFERENCES products(product_id),
    stage VARCHAR(50) NOT NULL,
    probability DECIMAL(5,2) NOT NULL CHECK (probability BETWEEN 0 AND 100),
    expected_close_date DATE NOT NULL,
    expected_revenue DECIMAL(14,2) NOT NULL CHECK (expected_revenue >= 0)
);

CREATE TABLE targets (
    target_id SERIAL PRIMARY KEY,
    salesperson_id INT NOT NULL REFERENCES salespeople(salesperson_id),
    year INT NOT NULL,
    month INT NOT NULL CHECK (month BETWEEN 1 AND 12),
    monthly_target DECIMAL(14,2) NOT NULL CHECK (monthly_target >= 0) -- widened from (14,2) already sufficient, kept consistent with annual_target
);

CREATE TABLE calendar (
    date DATE PRIMARY KEY,
    year INT NOT NULL,
    quarter INT NOT NULL CHECK (quarter BETWEEN 1 AND 4),
    month INT NOT NULL CHECK (month BETWEEN 1 AND 12),
    month_name VARCHAR(20) NOT NULL,
    week INT NOT NULL CHECK (week BETWEEN 1 AND 53),
    day INT NOT NULL CHECK (day BETWEEN 1 AND 31),
    financial_year VARCHAR(20) NOT NULL
);

CREATE TABLE customer_master (
    customer_master_id SERIAL PRIMARY KEY,
    company_name VARCHAR(100) NOT NULL UNIQUE,
    industry VARCHAR(50) NOT NULL
);
