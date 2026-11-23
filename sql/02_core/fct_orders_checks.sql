-- fct_orders_checks.sql
-- Amaç : fct_orders tablosunun doğru kurulduğunu doğrulamak (veri testleri).
-- Her kontrol ayrı çalıştırıldı; sonuçlar her kontrolün başında.

-- Kontrol 1: Her sipariş tek satır mı + rakamlar stg_events kontrol 6 ile aynı mı?
-- Beklenen: row_count = orders = 5.283 | purchasers = 4.408 | revenue_usd = 338.153
-- Sonuç   : 5.283 | 5.283 | 4.408 | 338.153 | gelirsiz sipariş 0 | numarasız sipariş 832  ✓
SELECT
  COUNT(*)                         AS row_count,
  COUNT(DISTINCT order_id)         AS orders,
  COUNT(DISTINCT user_pseudo_id)   AS purchasers,
  ROUND(SUM(revenue_usd), 2)       AS revenue_usd,
  COUNTIF(revenue_usd IS NULL)     AS orders_without_revenue,
  COUNTIF(NOT has_transaction_id)  AS orders_without_transaction_id
FROM `ga4-funnel-analytics-515610.ga4_funnel.fct_orders`;


-- Kontrol 2: İlk sipariş ve tekrar alım
-- Beklenen: first_orders = alıcı sayısı (4.408), repeat_orders = 5.283 - 4.408 = 875
-- Sonuç   : 4.408 | 875 | en çok sipariş veren kullanıcı 16 sipariş  ✓  -> aykırı değer kontrolü: Kontrol 3
SELECT
  COUNTIF(order_number = 1)  AS first_orders,
  COUNTIF(order_number > 1)  AS repeat_orders,
  MAX(order_number)          AS max_orders_per_user
FROM `ga4-funnel-analytics-515610.ga4_funnel.fct_orders`;


-- Kontrol 3: Kullanıcı başına sipariş dağılımı (aykırı değerler gelir metriğini etkiliyor mu?)
-- Sonuç:
--   orders_per_user | users | revenue_usd | pct_of_revenue
--   1               | 3.880 | 249.190     | 73,69
--   2               |   369 |  51.639     | 15,27
--   3               |    92 |  16.573     |  4,90
--   4               |    22 |   4.665     |  1,38
--   5               |    15 |   6.007     |  1,78
--   6               |    15 |   3.711     |  1,10
--   7               |     5 |   1.591     |  0,47
--   8               |     4 |   1.172     |  0,35
--   9               |     1 |     270     |  0,08
--   10              |     2 |   1.759     |  0,52
--   11              |     1 |     280     |  0,08
--   13              |     1 |     752     |  0,22
--   16              |     1 |     544     |  0,16
-- Sağlamalar: Σ users = 4.408 | Σ (orders × users) = 5.283 | Σ revenue = 338.153  ✓
-- Yorum:
--   * 10+ sipariş veren 5 kullanıcının gelir payı %0,98 -> aykırı değerler metriği etkilemiyor, dokunulmadı.
--     16 siparişli kullanıcının toplam harcaması 544 USD (sipariş başına ~34 USD).
--   * Tekrar alım oranı: 528 / 4.408 = %12,0 (2+ sipariş veren alıcılar).
--   * Bu %12'lik müşteri grubu gelirin %26,3'ünü getiriyor.
WITH per_user AS (
  SELECT
    user_pseudo_id,
    COUNT(*)         AS orders,
    SUM(revenue_usd) AS revenue_usd
  FROM `ga4-funnel-analytics-515610.ga4_funnel.fct_orders`
  GROUP BY user_pseudo_id
)

SELECT
  orders                                                            AS orders_per_user,
  COUNT(*)                                                          AS users,
  ROUND(SUM(revenue_usd), 0)                                        AS revenue_usd,
  ROUND(100 * SUM(revenue_usd) / SUM(SUM(revenue_usd)) OVER (), 2)  AS pct_of_revenue
FROM per_user
GROUP BY orders
ORDER BY orders;
