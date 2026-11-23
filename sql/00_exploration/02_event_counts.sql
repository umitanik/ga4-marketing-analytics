-- 02_event_counts.sql
-- Amaç : Hangi olay türlerinin olduğunu, kaç kez ve kaç farklı kullanıcı tarafından yapıldığını görmek.
-- Öne çıkanlar:
--   page_view        1.350.428 olay | 269.792 kullanıcı
--   session_start      354.970 olay | 267.116 kullanıcı  -> kullanıcı başına ~1,33 oturum (retention düşük)
--   first_visit        257.462 olay | 257.314 kullanıcı  -> ~12.800 kullanıcının dönem içinde first_visit'i yok
--   view_item          386.068 olay |  61.252 kullanıcı
--   view_promotion     190.104 olay | 102.443 kullanıcı
--   select_promotion     9.450 olay |   8.164 kullanıcı  -> kampanya tıklama oranı ~%8
--   add_to_cart         58.543 olay |  12.545 kullanıcı
--   begin_checkout      38.757 olay |   9.715 kullanıcı
--   add_shipping_info   19.722 olay |   9.714 kullanıcı  -> begin_checkout ile neredeyse aynı (şüpheli)
--   add_payment_info    13.899 olay |   5.751 kullanıcı
--   purchase             5.692 olay |   4.419 kullanıcı
--   view_item_list          71 olay |      44 kullanıcı  -> takip eksik
-- Bkz: docs/data_quality.md (not 1, 2, 3)

SELECT
  event_name,
  COUNT(*)                       AS event_count,
  COUNT(DISTINCT user_pseudo_id) AS user_count
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
GROUP BY event_name
ORDER BY event_count DESC;
