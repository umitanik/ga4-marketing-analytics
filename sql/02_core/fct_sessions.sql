-- fct_sessions.sql
-- Katman : 02_core (fact)
-- Amaç   : Oturum başına TEK satır: süre, etkileşim, görüntülenen ürün, funnel adımları, sipariş ve gelir.
-- Neden  : Funnel, kanal kalitesi, retention ve lojistik regresyon (ilk oturum davranışı) bu tabloya dayanacak.
--
-- Kurallar:
--   * Oturum = session_id (her olayda dolu; session_start olayına güvenilmedi, docs/data_quality.md not 7).
--   * Funnel adımları için her adımın oturumdaki İLK zamanı tutulur (sıralı funnel mart katmanında
--     bu zamanlar karşılaştırılarak kurulacak). add_shipping_info kullanılmadı (not 1).
--   * Satın alma ve gelir ham purchase olaylarından DEĞİL, fct_orders'tan gelir (not 8).
--     Siparişler JOIN'den ÖNCE oturum bazında toplanır; yoksa 2 siparişli oturumlar iki satıra çoğalırdı (fan-out).
--   * session_index: kullanıcının dönem içindeki kaçıncı oturumu. Dönen kullanıcılar (dim_users.is_new_user = false)
--     için 1 numaralı oturum gerçek ilk oturumları değildir.

CREATE OR REPLACE TABLE `ga4-funnel-analytics-515610.ga4_funnel.fct_sessions`
CLUSTER BY user_pseudo_id
AS

WITH session_events AS (
  SELECT
    session_id,
    user_pseudo_id,
    MIN(event_date)                                           AS session_date,
    MIN(event_ts)                                             AS session_start_ts,
    MAX(event_ts)                                             AS session_end_ts,
    COUNT(*)                                                  AS events,
    COUNTIF(event_name = 'page_view')                         AS page_views,
    COUNTIF(event_name = 'view_item')                         AS item_views,
    ROUND(IFNULL(SUM(engagement_time_msec), 0) / 1000, 1)     AS engagement_time_sec,
    MIN(IF(event_name = 'view_item',        event_ts, NULL))  AS view_item_ts,
    MIN(IF(event_name = 'add_to_cart',      event_ts, NULL))  AS add_to_cart_ts,
    MIN(IF(event_name = 'begin_checkout',   event_ts, NULL))  AS begin_checkout_ts,
    MIN(IF(event_name = 'add_payment_info', event_ts, NULL))  AS add_payment_info_ts
  FROM `ga4-funnel-analytics-515610.ga4_funnel.stg_events`
  GROUP BY session_id, user_pseudo_id
),

session_orders AS (
  SELECT
    session_id,
    COUNT(*)         AS orders,
    SUM(revenue_usd) AS revenue_usd,
    MIN(order_ts)    AS purchase_ts
  FROM `ga4-funnel-analytics-515610.ga4_funnel.fct_orders`
  GROUP BY session_id
)

SELECT
  s.*,
  TIMESTAMP_DIFF(s.session_end_ts, s.session_start_ts, SECOND)                    AS session_duration_sec,
  ROW_NUMBER() OVER (PARTITION BY s.user_pseudo_id ORDER BY s.session_start_ts)   AS session_index,
  o.purchase_ts,
  IFNULL(o.orders, 0)                AS orders,
  IFNULL(o.revenue_usd, 0)           AS revenue_usd,
  s.view_item_ts IS NOT NULL         AS viewed_item,
  s.add_to_cart_ts IS NOT NULL       AS added_to_cart,
  s.begin_checkout_ts IS NOT NULL    AS began_checkout,
  s.add_payment_info_ts IS NOT NULL  AS added_payment_info,
  o.session_id IS NOT NULL           AS purchased
FROM session_events AS s
LEFT JOIN session_orders AS o
  ON s.session_id = o.session_id;
