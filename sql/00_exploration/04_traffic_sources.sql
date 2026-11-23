-- 04_traffic_sources.sql
-- Amaç : Kullanıcıların hangi kanaldan geldiğini görmek (traffic_source = kullanıcının ilk geldiği kanal).
--
-- Sonuç (ilk 8 satır):
--   medium         | source                          | users
--   organic        | google                          | 103.487
--   (none)         | (direct)                        |  75.951
--   <Other>        | <Other>                         |  51.037   <- anonimleştirmede gizlenmiş
--   referral       | <Other>                         |  32.880
--   referral       | shop.googlemerchandisestore.com |  26.065   <- self-referral (takip hatası)
--   (data deleted) | (data deleted)                  |  17.948   <- gizlilik nedeniyle silinmiş
--   cpc            | google                          |  15.527   <- Google Ads (ücretli)
--   organic        | <Other>                         |  10.095
--
-- Bulgu: Satırların toplamı ~333.388, gerçek kullanıcı sayısı 270.154.
--        Bazı kullanıcılar birden fazla kanalda sayılıyor -> bkz. 06 ve 07 numaralı sorgular.
-- Bkz: docs/data_quality.md (not 5, 6)

SELECT
  traffic_source.medium,
  traffic_source.source,
  COUNT(DISTINCT user_pseudo_id) AS users
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
GROUP BY 1, 2
ORDER BY users DESC
LIMIT 20;
