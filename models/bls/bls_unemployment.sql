{{
    config(
        materialized='table'
    )
}}


WITH pivot_unemployment AS (
  SELECT 
    year
    , date
    , period
    , max(case when series_id = 'LNU04076975' then value else null end) AS unemployment_rate
    , max(case when series_id = 'LNU03076975' then value else null end) AS unemployment_level
  FROM 
    `bigquery-public-data.bls.unemployment_cps`
  WHERE
    year = 2020
    /* Series ID is a unique ID for each metric 
        This series ID covers the unemployment rate for all people 18 and over
    */
    AND series_id in ('LNU04076975', 'LNU03076975')
  GROUP BY 
    year
    , date
    , period
  ORDER BY
    year DESC
    , date ASC
)
SELECT
    year
    , date
    , period
    , unemployment_rate 
    , unemployment_level AS unemployment_level_millions
    , round(unemployment_level / (unemployment_rate / 100), 0) AS total_level_millions
FROM 
  pivot_unemployment