-- mart_channel_quality.sql
-- Katman : 03_marts
-- Amaç   : Kanal (× cihaz) bazında kullanıcı değeri: geri dönüş, dönüşüm, sipariş, gelir, tekrar alım.
-- İş sorusu: 2. En çok kullanıcıyı getiren kanal ile en değerli kullanıcıyı getiren kanal aynı mı?
--
-- Kurallar:
--   * Kanal ve cihaz dim_users'tan (her kullanıcı tek kanal, first-touch).
--   * Siparişler ve gelir fct_orders'tan (tekrarları temizlenmiş).
--   * Oturumlar ve siparişler JOIN'den ÖNCE kullanıcı bazında toplanır (fan-out olmasın).
--   * Tabloda ORAN değil SAYI ve TOPLAM tutulur. Oranlar analiz sorgusunda / Tableau'da hesaplanır:
--       dönüşüm oranı        = purchasers / users
--       kullanıcı başına gelir = revenue_usd / users
--       ortalama sipariş tutarı = revenue_usd / orders
--       tekrar alım oranı     = repeat_purchasers / purchasers
--       geri dönüş oranı      = returning_visitors / users

CREATE OR REPLACE TABLE `ga4-funnel-analytics-515610.ga4_funnel.mart_channel_quality`
AS

WITH user_sessions AS (
  SELECT
    user_pseudo_id,
    COUNT(*) AS sessions
  FROM `ga4-funnel-analytics-515610.ga4_funnel.fct_sessions`
  GROUP BY user_pseudo_id
),

user_orders AS (
  SELECT
    user_pseudo_id,
    COUNT(*)         AS orders,
    SUM(revenue_usd) AS revenue_usd
  FROM `ga4-funnel-analytics-515610.ga4_funnel.fct_orders`
  GROUP BY user_pseudo_id
),

users AS (
  SELECT
    u.channel_group,
    u.device_category,
    u.is_new_user,
    s.sessions,
    IFNULL(o.orders, 0)      AS orders,
    IFNULL(o.revenue_usd, 0) AS revenue_usd
  FROM `ga4-funnel-analytics-515610.ga4_funnel.dim_users` AS u
  LEFT JOIN user_sessions AS s ON u.user_pseudo_id = s.user_pseudo_id
  LEFT JOIN user_orders   AS o ON u.user_pseudo_id = o.user_pseudo_id
)

SELECT
  channel_group,
  device_category,
  COUNT(*)                    AS users,
  COUNTIF(is_new_user)        AS new_users,
  SUM(sessions)               AS sessions,
  COUNTIF(sessions >= 2)      AS returning_visitors,
  COUNTIF(orders >= 1)        AS purchasers,
  COUNTIF(orders >= 2)        AS repeat_purchasers,
  SUM(orders)                 AS orders,
  ROUND(SUM(revenue_usd), 2)  AS revenue_usd
FROM users
GROUP BY channel_group, device_category;
