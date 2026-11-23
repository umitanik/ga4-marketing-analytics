-- 07_source_count_distribution.sql
-- Amaç : Kullanıcıların kaç farklı kanal bilgisine sahip olduğunun dağılımı.
-- Teknik: CTE + SUM(COUNT(*)) OVER () ile toplama oranlama.
--         Burada toplamak doğru, çünkü her kullanıcı tam olarak bir gruptadır.
--
-- Sonuç:
--   source_count | users   | pct_of_users
--   1            | 227.894 | 84,36
--   2            |  29.029 | 10,75
--   3            |   7.940 |  2,94
--   4            |   3.384 |  1,25
--   5            |   1.430 |  0,53
--   6            |     412 |  0,15
--   7            |      62 |  0,02
--   8            |       3 |  0,00
--
-- Sağlamalar (hepsi tuttu):
--   Σ users                       = 270.154  (toplam kullanıcı)
--   Σ users (source_count >= 2)   =  42.260  (06 numaralı sorgu)
--   Σ (source_count × users)      = 333.388  (04 numaralı sorgudaki satır toplamı)

WITH user_sources AS (
  SELECT
    user_pseudo_id,
    COUNT(DISTINCT CONCAT(traffic_source.medium, ' / ', traffic_source.source)) AS source_count
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  GROUP BY user_pseudo_id
)

SELECT
  source_count,
  COUNT(*) AS users,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_users
FROM user_sources
GROUP BY source_count
ORDER BY source_count;
