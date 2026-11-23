-- 01_dataset_overview.sql
-- Amaç : Verinin genel tablosunu çıkarmak (olay sayısı, tekil kullanıcı, tarih aralığı).
-- Sonuç: 4.295.584 olay | 270.154 tekil kullanıcı | 2020-11-01 – 2021-01-31 (92 gün)
-- Not  : Kullanıcı başına ortalama ~15,9 olay, günde ortalama ~46.700 olay.
--        Ortalama, az sayıdaki yoğun kullanıcı yüzünden çarpık olabilir; medyana ayrıca bakılacak.

SELECT
  COUNT(*)                       AS event_count,
  COUNT(DISTINCT user_pseudo_id) AS user_count,
  MIN(event_date)                AS first_day,
  MAX(event_date)                AS last_day
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`;
