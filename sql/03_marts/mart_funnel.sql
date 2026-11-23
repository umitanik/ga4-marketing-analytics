-- mart_funnel.sql
-- Katman : 03_marts
-- Amaç   : Kullanıcı bazlı SIRALI funnel, kanal ve cihaz kırılımında.
-- İş sorusu: 1. Kullanıcılar hangi adımda en çok kayboluyor? Bu, kanala ve cihaza göre değişiyor mu?
--
-- Kurallar:
--   * Ana funnel adımları: view_item -> begin_checkout -> add_payment_info -> purchase
--     - add_shipping_info kullanılmadı (docs/data_quality.md not 1).
--     - add_to_cart funnel'ın KAPISI DEĞİL (not 9): ödemeye geçenlerin %42'si hiç sepete eklemeden
--       ödemeye geçmiş ("hemen al" akışı ya da eksik takip). Sepete ekleme bilgi amaçlı ayrı kolon.
--   * SIRALI: Bir adım ancak bir önceki adımdan SONRA yapıldıysa sayılır (not 4).
--   * Kullanıcı bazlı ve oturumlar arası: adımlar farklı oturumlarda olabilir.
--   * Satın alma adımı fct_orders'tan (tekrarları temizlenmiş siparişler, not 8).
--   * Kanal ve cihaz dim_users'tan (her kullanıcı tek kanal, first-touch).
--   * Tabloda ORAN değil SAYI tutulur. Oranlar gruplar arasında toplanamaz; sayılar toplanır.
--   * Her step CTE'si kullanıcı başına tek satır, bu yüzden LEFT JOIN'lerde fan-out yok.
--
-- Sürüm geçmişi:
--   v1: add_to_cart zorunlu adımdı -> sepet->ödeme %40,1, genel dönüşüm %1,05 (sepetsiz ödemeye geçenler elendi).
--   v2: add_to_cart bilgi amaçlı (bu sürüm).

CREATE OR REPLACE TABLE `ga4-funnel-analytics-515610.ga4_funnel.mart_funnel`
AS

WITH step1 AS (
  -- Ürün görüntüleme (ilk)
  SELECT user_pseudo_id, MIN(event_ts) AS ts
  FROM `ga4-funnel-analytics-515610.ga4_funnel.stg_events`
  WHERE event_name = 'view_item'
  GROUP BY user_pseudo_id
),

cart AS (
  -- Bilgi amaçlı: ürün görüntülemeden sonra sepete ekleme. Funnel'ın kapısı DEĞİL.
  SELECT e.user_pseudo_id, MIN(e.event_ts) AS ts
  FROM `ga4-funnel-analytics-515610.ga4_funnel.stg_events` AS e
  JOIN step1 AS p ON e.user_pseudo_id = p.user_pseudo_id
  WHERE e.event_name = 'add_to_cart'
    AND e.event_ts >= p.ts
  GROUP BY e.user_pseudo_id
),

step2 AS (
  -- Ödemeye geçme (ürün görüntülemeden sonra)
  SELECT e.user_pseudo_id, MIN(e.event_ts) AS ts
  FROM `ga4-funnel-analytics-515610.ga4_funnel.stg_events` AS e
  JOIN step1 AS p ON e.user_pseudo_id = p.user_pseudo_id
  WHERE e.event_name = 'begin_checkout'
    AND e.event_ts >= p.ts
  GROUP BY e.user_pseudo_id
),

step3 AS (
  -- Ödeme bilgisi (ödemeye geçmeden sonra)
  SELECT e.user_pseudo_id, MIN(e.event_ts) AS ts
  FROM `ga4-funnel-analytics-515610.ga4_funnel.stg_events` AS e
  JOIN step2 AS p ON e.user_pseudo_id = p.user_pseudo_id
  WHERE e.event_name = 'add_payment_info'
    AND e.event_ts >= p.ts
  GROUP BY e.user_pseudo_id
),

step4 AS (
  -- Satın alma (ödeme bilgisinden sonra, temizlenmiş siparişler)
  SELECT o.user_pseudo_id, MIN(o.order_ts) AS ts
  FROM `ga4-funnel-analytics-515610.ga4_funnel.fct_orders` AS o
  JOIN step3 AS p ON o.user_pseudo_id = p.user_pseudo_id
  WHERE o.order_ts >= p.ts
  GROUP BY o.user_pseudo_id
),

user_funnel AS (
  SELECT
    u.channel_group,
    u.device_category,
    s1.user_pseudo_id IS NOT NULL AS reached_view_item,
    c.user_pseudo_id  IS NOT NULL AS reached_add_to_cart,
    s2.user_pseudo_id IS NOT NULL AS reached_begin_checkout,
    s3.user_pseudo_id IS NOT NULL AS reached_add_payment_info,
    s4.user_pseudo_id IS NOT NULL AS reached_purchase
  FROM `ga4-funnel-analytics-515610.ga4_funnel.dim_users` AS u
  LEFT JOIN step1 AS s1 ON u.user_pseudo_id = s1.user_pseudo_id
  LEFT JOIN cart  AS c  ON u.user_pseudo_id = c.user_pseudo_id
  LEFT JOIN step2 AS s2 ON u.user_pseudo_id = s2.user_pseudo_id
  LEFT JOIN step3 AS s3 ON u.user_pseudo_id = s3.user_pseudo_id
  LEFT JOIN step4 AS s4 ON u.user_pseudo_id = s4.user_pseudo_id
)

SELECT
  channel_group,
  device_category,
  COUNT(*)                          AS users,
  COUNTIF(reached_view_item)        AS view_item_users,
  COUNTIF(reached_add_to_cart)      AS add_to_cart_users,      -- bilgi amaçlı, funnel kapısı değil
  COUNTIF(reached_begin_checkout)   AS begin_checkout_users,
  COUNTIF(reached_add_payment_info) AS add_payment_info_users,
  COUNTIF(reached_purchase)         AS purchase_users
FROM user_funnel
GROUP BY channel_group, device_category;
