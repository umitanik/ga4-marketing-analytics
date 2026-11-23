-- 06_multi_source_users.sql
-- Amaç : 04 numaralı sorgudaki toplam farkının nedenini doğrulamak.
--        Olaydan olaya farklı kanal bilgisi olan kaç kullanıcı var?
-- Teknik: HAVING (gruplamadan sonra filtreleme)
-- Sonuç: 42.260 kullanıcı (toplamın %15,64'ü)

SELECT COUNT(*) AS users_with_multiple_sources
FROM (
  SELECT user_pseudo_id
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  GROUP BY user_pseudo_id
  HAVING COUNT(DISTINCT CONCAT(traffic_source.medium, ' / ', traffic_source.source)) > 1
);
