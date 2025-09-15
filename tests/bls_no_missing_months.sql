{% set y0 = var('start_year', 2019) %}
{% set y1 = var('end_year',   2020) %}

-- Months that exist in SOURCE for BOTH series (exclude M13)
WITH src AS (
  SELECT
    SAFE.PARSE_DATE(
      '%Y-%m-%d',
      CONCAT(CAST(year AS STRING), '-',
             LPAD(CAST(SAFE_CAST(SUBSTR(period,2) AS INT64) AS STRING), 2, '0'),
             '-01')
    ) AS month_start,
    series_id
  FROM {{ source('bls','unemployment_cps') }}
  WHERE REGEXP_CONTAINS(period, '^M(0[1-9]|1[0-2])$')
    AND series_id IN ('LNU04076975','LNU03076975')
    AND year BETWEEN {{ y0 }} AND {{ y1 }}
),
source_months AS (
  SELECT month_start
  FROM src
  GROUP BY month_start
  HAVING COUNT(DISTINCT series_id) = 2         -- require BOTH series present
),
model_months AS (
  SELECT DATE_TRUNC(date, MONTH) AS month_start
  FROM {{ ref('bls_unemployment') }}
  WHERE EXTRACT(YEAR FROM date) BETWEEN {{ y0 }} AND {{ y1 }}
  GROUP BY 1
)
-- Fail on any source-backed month that is missing in the model
SELECT s.month_start
FROM source_months s
LEFT JOIN model_months m USING (month_start)
WHERE m.month_start IS NULL
