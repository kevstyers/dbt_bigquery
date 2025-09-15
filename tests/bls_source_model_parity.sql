{% set y0 = var('start_year', 2019) %}
{% set y1 = var('end_year',   2020) %}

WITH source_months AS (
  SELECT
    SAFE.PARSE_DATE(
      '%Y-%m-%d',
      CONCAT(CAST(year AS STRING), '-',
             LPAD(CAST(SAFE_CAST(SUBSTR(period, 2) AS INT64) AS STRING), 2, '0'),
             '-01')
    ) AS month_start
  FROM {{ source('bls','unemployment_cps') }}
  WHERE period LIKE 'M__'
    AND cast(replace(period, 'M', '') as int) between 1 and 12
    AND series_id IN ('LNU04076975','LNU03076975')
    AND year BETWEEN {{ y0 }} AND {{ y1 }}
  GROUP BY 1
),
model_months AS (
  SELECT DATE_TRUNC(date, MONTH) AS month_start
  FROM {{ ref('bls_unemployment') }}
  WHERE EXTRACT(YEAR FROM date) BETWEEN {{ y0 }} AND {{ y1 }}
  GROUP BY 1
),
counts AS (
  SELECT
    (SELECT COUNT(*) FROM source_months) AS source_cnt,
    (SELECT COUNT(*) FROM model_months)  AS model_cnt
)
-- Singular tests fail if they return rows:
SELECT source_cnt, model_cnt
FROM counts
WHERE source_cnt <> model_cnt