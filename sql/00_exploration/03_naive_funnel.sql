-- 03_naive_funnel.sql
-- Amaç : Funnel adımlarındaki kullanıcı sayılarını ve dönüşüm oranlarını tek sorguda hesaplamak.
-- Teknik: CTE, CASE WHEN, CROSS JOIN, LAG() window function
--
-- Sonuç:
--   step | event_name        | users  | pct_of_total | pct_of_previous
--   1    | view_item         | 61.252 | 22,67        | 22,67
--   2    | add_to_cart       | 12.545 |  4,64        | 20,48
--   3    | begin_checkout    |  9.715 |  3,60        | 77,44
--   4    | add_shipping_info |  9.714 |  3,60        | 99,99   <- şüpheli adım
--   5    | add_payment_info  |  5.751 |  2,13        | 59,20
--   6    | purchase          |  4.419 |  1,64        | 76,84
--
-- Yorum: En büyük kayıplar funnel'ın başında (gelen -> ürün görüntüleme, ürün -> sepet).
--        Ödeme adımları görece iyi.
-- Uyarı: Bu "sırasız" bir funnel. Kullanıcı sayıları birbirine bölünüyor; adımların sırayla
--        yapılıp yapılmadığı kontrol edilmiyor. Final funnel mart katmanında kurulacak.
--
-- Notlar:
--   * Toplam kullanıcı ayrı CTE'de COUNT(DISTINCT) ile hesaplanıyor. Olaylardaki kullanıcıları
--     toplamak yanlış olur, çünkü aynı kişi birden fazla adımda sayılır.
--   * BigQuery'de "/" her zaman ondalıklı sonuç verir. PostgreSQL / SQL Server'da tam sayı
--     bölmesi olur; orada 100.0 * a / b yazmak gerekir.

WITH event_users AS (
  SELECT
    event_name,
    COUNT(DISTINCT user_pseudo_id) AS users
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE event_name IN ('view_item', 'add_to_cart', 'begin_checkout',
                       'add_shipping_info', 'add_payment_info', 'purchase')
  GROUP BY event_name
),

total AS (
  SELECT COUNT(DISTINCT user_pseudo_id) AS total_users
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
),

funnel AS (
  SELECT
    CASE event_name
      WHEN 'view_item'         THEN 1
      WHEN 'add_to_cart'       THEN 2
      WHEN 'begin_checkout'    THEN 3
      WHEN 'add_shipping_info' THEN 4
      WHEN 'add_payment_info'  THEN 5
      WHEN 'purchase'          THEN 6
    END AS step,
    event_name,
    users
  FROM event_users
)

SELECT
  f.step,
  f.event_name,
  f.users,
  ROUND(100 * f.users / t.total_users, 2) AS pct_of_total,
  ROUND(100 * f.users / COALESCE(LAG(f.users) OVER (ORDER BY f.step), t.total_users), 2) AS pct_of_previous
FROM funnel AS f
CROSS JOIN total AS t
ORDER BY f.step;
