-- 05_event_params_unnest.sql
-- Amaç : event_params içindeki iç içe yapıyı (ARRAY<STRUCT<key, value>>) görmek.
-- Teknik: UNNEST, olayın parametre listesini açıp her parametreyi ayrı satır yapar.
-- Not  : Sadece tek günlük tabloya bakılıyor (events_20210131), taranan veri az olsun diye.
--        ga_session_id, page_title, source, medium gibi anahtarlar staging katmanında kolona çevrilecek.

SELECT
  event_name,
  param.key,
  param.value.string_value,
  param.value.int_value
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_20210131`,
  UNNEST(event_params) AS param
WHERE event_name = 'page_view'
LIMIT 50;
