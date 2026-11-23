-- mart_first_session.sql
-- Katman : 03_marts (modelleme veri seti)
-- Amaç   : Yeni kullanıcı başına TEK satır: ilk oturumdaki davranışlar + 7 gün içinde satın aldı mı.
-- İş sorusu: 6. İlk ziyaretteki hangi davranışlar satın alma olasılığını artırıyor? (lojistik regresyon)
--
-- Kurallar:
--   * Sadece yeni kullanıcılar (ilk oturumları gerçekten ilk ziyaretleri).
--   * Hedef: purchased_7d = ilk ziyaret gününden itibaren 7 gün içinde (gün 0-6) sipariş verdi mi.
--     Herkese EŞİT süre tanımak için sabit pencere (right censoring, bkz. mart_cohort_retention):
--     bu yüzden sadece ilk ziyareti 2021-01-24 ve öncesinde olanlar dahil (7 günü veri içinde kalanlar).
--   * Sipariş bilgisi fct_orders'tan (gelir değil sipariş kullanıldığı için 26 Ocak gelir arızası etkilemiyor).
--   * Özellikler SADECE ilk oturumdan. begin_checkout / add_payment_info özellik olarak KULLANILMADI:
--     bunlar satın almanın kendisinin parçası, hedefi "sızdırır" (target leakage).
--   * period: ilk ziyaretin dönemi (sezonsallık kontrolü için).
--   * purchased_first_session: satın alma İLK OTURUMUN İÇİNDE mi oldu? Sağlamlık kontrolü için.
--     İlk oturumda satın alanların etkileşim süresi, ödeme yaparken geçen süreyi de içerir; bu yüzden ilk modeldeki
--     davranış etkilerinin bir kısmı satın almanın kendisinden gelebilir. Notebook'ta bu kullanıcılar çıkarılıp
--     model tekrar kurulur.
--
-- Sürüm geçmişi:
--   v1: purchased_first_session yoktu (ilk model: pseudo R² 0,375, AUC 0,937; şüpheli derecede yüksek).
--   v2: purchased_first_session eklendi (bu sürüm).

CREATE OR REPLACE TABLE `ga4-funnel-analytics-515610.ga4_funnel.mart_first_session`
AS

WITH new_users AS (
  SELECT
    user_pseudo_id,
    first_visit_date,
    channel_group,
    device_category
  FROM `ga4-funnel-analytics-515610.ga4_funnel.dim_users`
  WHERE is_new_user
    AND first_visit_date <= DATE '2021-01-24'
),

first_sessions AS (
  SELECT
    user_pseudo_id,
    events,
    page_views,
    item_views,
    engagement_time_sec,
    session_duration_sec,
    add_to_cart_ts IS NOT NULL AS added_to_cart,
    purchased                  AS purchased_first_session
  FROM `ga4-funnel-analytics-515610.ga4_funnel.fct_sessions`
  WHERE session_index = 1
),

first_orders AS (
  SELECT
    user_pseudo_id,
    MIN(order_date) AS first_order_date
  FROM `ga4-funnel-analytics-515610.ga4_funnel.fct_orders`
  GROUP BY user_pseudo_id
)

SELECT
  u.user_pseudo_id,
  u.first_visit_date,
  u.channel_group,
  u.device_category,
  CASE
    WHEN u.first_visit_date < DATE '2020-11-23' THEN '1_kasim'
    WHEN u.first_visit_date < DATE '2020-12-21' THEN '2_sezon'
    WHEN u.first_visit_date < DATE '2021-01-04' THEN '3_tatil'
    ELSE '4_ocak'
  END                       AS period,
  s.events,
  s.page_views,
  s.item_views,
  s.engagement_time_sec,
  s.session_duration_sec,
  s.added_to_cart,
  s.purchased_first_session,
  IFNULL(
    o.first_order_date >= u.first_visit_date
    AND o.first_order_date <= DATE_ADD(u.first_visit_date, INTERVAL 6 DAY),
    FALSE
  )                         AS purchased_7d
FROM new_users AS u
JOIN first_sessions AS s
  ON u.user_pseudo_id = s.user_pseudo_id
LEFT JOIN first_orders AS o
  ON u.user_pseudo_id = o.user_pseudo_id;
