-- mart_daily_kpis.sql
-- Katman : 03_marts
-- Amaç   : Gün × kanal bazında temel KPI'lar: oturum, aktif kullanıcı, yeni kullanıcı, funnel oturumları,
--          sipariş, gelir. Dashboard'daki zaman serisi grafikleri bu tabloya bağlanacak.
-- İş sorusu: 4. Dönüşümün belirgin şekilde değiştiği bir dönem var mı, nedeni ne?
--
-- Kurallar:
--   * Oturum metrikleri fct_sessions'tan (session_date = oturumun başladığı gün).
--   * Sipariş ve gelir fct_orders'tan (order_date = siparişin günü, tekrarları temizlenmiş).
--   * Yeni kullanıcı = o gün first_visit yapan kullanıcı (dim_users).
--   * Kanal dim_users'tan (her kullanıcı tek kanal, first-touch).
--   * Üç kaynak JOIN'den ÖNCE gün × kanal bazında toplanır (fan-out olmasın).
--   * DİKKAT: active_users ve purchasers tekil kullanıcı sayılarıdır. Kanallar arasında (aynı gün içinde)
--     toplanabilir, çünkü her kullanıcı tek kanalda; ama GÜNLER arasında toplanamaz (aynı kişi birden çok gün
--     aktif olabilir). Diğer kolonlar (oturum, sipariş, gelir, yeni kullanıcı) her yönde toplanabilir.
--   * is_revenue_tracked: 26 Ocak 2021'den itibaren gelir takibi bozuk (siparişlerin %80+'ı 0 gelirli,
--     docs/data_quality.md not 10). Gelir metriklerinde bu günler dışarıda bırakılır ya da işaretlenir;
--     sipariş sayıları ve dönüşüm geçerli.
--
-- Sürüm geçmişi:
--   v1: bayraksız.
--   v2: is_revenue_tracked eklendi (bu sürüm).

CREATE OR REPLACE TABLE `ga4-funnel-analytics-515610.ga4_funnel.mart_daily_kpis`
AS

WITH daily_sessions AS (
  SELECT
    s.session_date                   AS date,
    u.channel_group,
    COUNT(*)                         AS sessions,
    COUNT(DISTINCT s.user_pseudo_id) AS active_users,
    COUNTIF(s.viewed_item)           AS sessions_with_item_view,
    COUNTIF(s.began_checkout)        AS sessions_with_checkout,
    COUNTIF(s.purchased)             AS purchase_sessions
  FROM `ga4-funnel-analytics-515610.ga4_funnel.fct_sessions` AS s
  JOIN `ga4-funnel-analytics-515610.ga4_funnel.dim_users` AS u
    ON s.user_pseudo_id = u.user_pseudo_id
  GROUP BY date, u.channel_group
),

daily_new_users AS (
  SELECT
    first_visit_date AS date,
    channel_group,
    COUNT(*)         AS new_users
  FROM `ga4-funnel-analytics-515610.ga4_funnel.dim_users`
  WHERE is_new_user
  GROUP BY date, channel_group
),

daily_orders AS (
  SELECT
    o.order_date                     AS date,
    u.channel_group,
    COUNT(*)                         AS orders,
    COUNT(DISTINCT o.user_pseudo_id) AS purchasers,
    SUM(o.revenue_usd)               AS revenue_usd
  FROM `ga4-funnel-analytics-515610.ga4_funnel.fct_orders` AS o
  JOIN `ga4-funnel-analytics-515610.ga4_funnel.dim_users` AS u
    ON o.user_pseudo_id = u.user_pseudo_id
  GROUP BY date, u.channel_group
)

SELECT
  s.date,
  s.channel_group,
  s.sessions,
  s.active_users,
  IFNULL(n.new_users, 0)              AS new_users,
  s.sessions_with_item_view,
  s.sessions_with_checkout,
  s.purchase_sessions,
  IFNULL(o.orders, 0)                 AS orders,
  IFNULL(o.purchasers, 0)             AS purchasers,
  ROUND(IFNULL(o.revenue_usd, 0), 2)  AS revenue_usd,
  s.date < DATE '2021-01-26'          AS is_revenue_tracked
FROM daily_sessions AS s
LEFT JOIN daily_new_users AS n
  ON s.date = n.date AND s.channel_group = n.channel_group
LEFT JOIN daily_orders AS o
  ON s.date = o.date AND s.channel_group = o.channel_group;
