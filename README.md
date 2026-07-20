# Industrial Equipment Supplier — Sales & Pipeline Analytics (PostgreSQL)

A simulated commercial analytics project for an Australian industrial equipment
supplier, built from the ground up in PostgreSQL: schema design, synthetic
data generation, and business analysis SQL — with real bugs found, diagnosed,
and fixed along the way.

## Business Problem

A commercial equipment supplier (earthmoving, material handling, power
equipment, site equipment, and compressors) sells through a team of regional
salespeople to businesses across Australia. Leadership wants to understand:

- Which states, products, and customers are driving the most revenue and profit
- How each salesperson is performing against their targets
- How much revenue is realistically sitting in the sales pipeline
- Where the business is underperforming, and why

This project builds the database, generates realistic transactional data, and
answers those questions with SQL.

## Tools Used

- **PostgreSQL** — database and query engine
- **pgAdmin** — SQL editor / interface
- **Power BI** — dashboard layer (Section 6)

## Database Schema

Eight tables, fully normalized with primary keys, foreign keys, `NOT NULL`,
`CHECK`, and `UNIQUE` constraints:

| Table | Purpose |
|---|---|
| `products` | 6 industrial equipment products across 5 categories |
| `salespeople` | 8 sales reps with region, hire date, and annual target |
| `customer_master` | 90 realistic Australian business names across 6 industries |
| `customers` | 500 generated customer records, weighted by state |
| `sales` | 10,000 sales transactions |
| `pipeline` | 800 open/closed sales opportunities |
| `targets` | Monthly revenue targets per salesperson |
| `calendar` | Date dimension table (2021–2025) for time intelligence |

See [`sql/01_schema.sql`](sql/01_schema.sql) for full DDL.

## Project Structure

```
sql/
├── 01_schema.sql              -- table definitions
├── 02_master_data.sql         -- products, salespeople, customer_master, customers
├── 03_reference_data.sql      -- calendar, initial targets
├── 04_sales_data.sql          -- 10,000 sales transactions (corrected version)
├── 05_pipeline_data.sql       -- 800 pipeline opportunities (corrected version)
├── 06_target_rescale_fix.sql  -- fixes unrealistic target values (see below)
├── 07_analysis_queries.sql    -- Section 5 business analysis queries
└── 08_views.sql               -- reusable views for Power BI
```

Run the files in numeric order against a fresh PostgreSQL database.

## Key Business Findings

- Revenue distribution across states closely tracked the underlying customer
  base weighting (NSW > VIC > QLD > WA > SA), with margin remarkably
  consistent (~26–27%) across every state — expected, since discounting and
  product mix were generated independently of geography.
- **Forklift F35** was the highest-volume product by sales count but sat in
  the **middle tier** for average profit per sale — a "sells a lot, thinner
  margin" product. **Excavator X200** and **Wheel Loader L150** sold less
  often but generated roughly 4x the average profit per sale.
- Salesperson performance didn't scale purely with deal count — some reps
  (e.g. those with the highest average deal size) generated strong revenue
  from fewer, larger sales rather than high sales volume.
- TAS, NT, and ACT customers make up a small share of the customer base
  (~8% combined) and, as a result, contribute a proportionally small share
  of total revenue — a realistic outcome of a smaller regional footprint
  rather than a data error (see Data Limitations).

## Data Limitations & Issues Found

Being upfront about the rough edges in a synthetic dataset — and how they
were found and resolved — is itself part of the analysis:

1. **Uncorrelated `LATERAL` subqueries collapsed random selection.** The
   first version of the sales/pipeline generation queries picked a random
   customer and salesperson using an uncorrelated `ORDER BY random() LIMIT 1`
   inside a `CROSS JOIN LATERAL`. Because the subquery didn't reference
   anything from the outer row, PostgreSQL evaluated it once and reused the
   result — every one of the 10,000 sales rows was assigned to the same
   customer and salesperson. **Fix:** rewrote the selection logic using
   `ROW_NUMBER()`/`COUNT()` window functions so each pick was genuinely
   correlated to a per-row random value.

2. **`CROSS JOIN LATERAL` silently dropped unmatched rows.** After fixing
   (1), customers in states with no resident salesperson (TAS/NT/ACT) were
   being silently excluded from `sales` and `pipeline` entirely — `CROSS
   JOIN LATERAL` behaves like an inner join, so when the state-matching
   subquery returned zero rows, the whole outer row disappeared before a
   fallback could run. **Fix:** changed the matched-salesperson block to
   `LEFT JOIN LATERAL ... ON true`, allowing a `NULL` result that a
   `COALESCE` fallback could then catch.

3. **Sales targets were set independently of product pricing.** Initial
   `annual_target` values (set during schema build, before any sales data
   existed) were roughly 25–35x smaller than the revenue actually generated
   once product prices and volumes were simulated — meaning every
   salesperson beat their target every month, making "actual vs target"
   analysis meaningless. **Fix:** recalculated targets as 90% of each
   salesperson's actual average annual revenue, and widened the affected
   columns (`DECIMAL(10,2)` → `DECIMAL(14,2)`) to accommodate the corrected
   values.

4. **Synthetic data constraints.** All data was generated with PostgreSQL's
   `random()` and `generate_series()` — customer IDs, product categories, and
   sale dates are independently randomized rather than causally linked, so
   some patterns (e.g. uniform margin across states/products) are artifacts
   of the generation method rather than genuine business dynamics a real
   dataset would show.

## SQL Skills Demonstrated

- Database design: primary/foreign keys, `CHECK`/`NOT NULL`/`UNIQUE` constraints
- Synthetic data generation: `generate_series()`, `random()`, weighted `CASE` distributions
- `CROSS JOIN LATERAL` / `LEFT JOIN LATERAL` and the correlation pitfalls of each
- Window functions: `ROW_NUMBER() OVER ()`, `COUNT(*) OVER ()`, `AVG(...) OVER ()`
- CTEs (including chained/multi-step CTEs) for readable, modular query logic
- `FILTER (WHERE ...)` for conditional aggregation
- `COALESCE` / `NULLIF` for null-safety and divide-by-zero protection
- Date/time functions: `EXTRACT()`, `TO_CHAR()`, date arithmetic
- Diagnosing and fixing real data-generation bugs by working backwards from
  unexpected query results rather than assuming the query was correct

## Resume Summary

> **SQL & Power BI Sales Analytics Project (Personal Project)**
> Designed and built a normalized PostgreSQL database simulating an
> Australian industrial equipment supplier's sales, pipeline, and target
> data. Wrote advanced SQL (CTEs, window functions, `LATERAL` joins,
> conditional aggregation) to analyze revenue, profit margin, product and
> salesperson performance, pipeline value, and target attainment. Identified
> and resolved two data-generation bugs and a target-scale data quality
> issue, validating each fix against expected statistical distributions
> before proceeding. Documented findings and limitations to support
> data-driven commercial decision-making.
> **Technologies:** PostgreSQL, SQL, pgAdmin, Power BI

## Roadmap

- [x] Section 1 — Master data & schema design
- [x] Section 2 — Reference data (calendar, targets)
- [x] Section 3 — Sales transaction data
- [x] Section 4 — Pipeline opportunity data
- [x] Section 5 — SQL business analysis & views
- [ ] Section 6 — Power BI dashboard
- [ ] Section 7 — Final polish, screenshots, write-up
