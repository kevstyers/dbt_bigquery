{{ config(
    materialized='incremental',
    incremental_strategy='merge',     
    unique_key='date',
    merge_update_columns=[],          
    on_schema_change='sync_all_columns',
    partition_by={"field": "date", "data_type": "date"},
    cluster_by=["year"]
) }}

{% set y0 = var('start_year', 2019) %}
{% set y1 = var('end_year',   2021) %}

WITH base AS (
  SELECT
    year,
    period,  -- 'M01'..'M12'
    SAFE.PARSE_DATE(
      '%Y-%m-%d',
      CONCAT(CAST(year AS STRING), '-',
             LPAD(CAST(SAFE_CAST(SUBSTR(period,2) AS INT64) AS STRING), 2, '0'),
             '-01')
    ) AS date,
    series_id,
    value
  FROM {{ source('bls','unemployment_cps') }}
  WHERE period LIKE 'M__'
    AND cast(replace(period, 'M', '') as int) between 1 and 12
    AND series_id IN ('LNU04076975','LNU03076975')
    AND year BETWEEN {{ y0 }} AND {{ y1 }}   -- window you’re loading (works for full + incremental)
),
pivot_unemployment AS (
  SELECT
    year,
    date,
    period,
    MAX(CASE WHEN series_id = 'LNU04076975' THEN value END) AS unemployment_rate_pct,
    MAX(CASE WHEN series_id = 'LNU03076975' THEN value END) AS unemployment_level_thousands
  FROM base
  GROUP BY year, date, period
)
SELECT
  year,
  date,
  period,
  unemployment_rate_pct,
  unemployment_level_thousands,
  ROUND(unemployment_level_thousands / (unemployment_rate_pct / 100.0), 0) AS total_labor_force_thousands,
  ROUND(unemployment_level_thousands / 1000.0, 3) AS unemployment_level_millions,
  ROUND((unemployment_level_thousands / (unemployment_rate_pct / 100.0)) / 1000.0, 3) AS total_labor_force_millions
FROM pivot_unemployment
