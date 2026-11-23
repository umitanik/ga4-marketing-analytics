-- fct_sessions_checks.sql
-- Amaç : fct_sessions tablosunun doğru kurulduğunu doğrulamak (veri testleri).
-- Her kontrol ayrı çalıştırıldı; sonuçlar her kontrolün başında.

-- Kontrol 1: Her oturum tek satır mı, bütün kullanıcılar var mı?
-- Beklenen: row_count = sessions = 360.129 (stg_events kontrol 3) | users = 270.154
-- Sonuç   : 360.129 | 360.129 | 270.154  ✓  (JOIN sonrası fan-out yok, kullanıcı kaybı yok)
SELECT
  COUNT(*)                       AS row_count,
  COUNT(DISTINCT session_id)     AS sessions,
  COUNT(DISTINCT user_pseudo_id) AS users
FROM `ga4-funnel-analytics-515610.ga4_funnel.fct_sessions`;


-- Kontrol 2: Siparişler ve gelir fct_orders ile tutuyor mu? (JOIN sonrası çoğalma/kayıp var mı?)
-- Beklenen: total_orders = 5.283 | total_revenue_usd = 338.153 | purchasers = 4.408
-- Sonuç   : 5.283 | 338.153 | 4.837 satın alma oturumu | 4.408 alıcı  ✓
-- Not     : Kullanıcı dönüşüm oranı 4.408 / 270.154 = %1,63; oturum dönüşüm oranı 4.837 / 360.129 = %1,34.
--           Kanal kalitesinde kullanıcı bazlı oran kullanılacak.
SELECT
  SUM(orders)                                        AS total_orders,
  ROUND(SUM(revenue_usd), 2)                         AS total_revenue_usd,
  COUNTIF(purchased)                                 AS purchase_sessions,
  COUNT(DISTINCT IF(purchased, user_pseudo_id, NULL)) AS purchasers
FROM `ga4-funnel-analytics-515610.ga4_funnel.fct_sessions`;


-- Kontrol 3: Oturum davranışı. Ortalama ve medyan.
-- Not: APPROX_QUANTILES(x, 2)[OFFSET(1)] yaklaşık medyanı verir (x'i 2 eşit parçaya bölen değer).
-- Sonuç: olay ort. 11,9 / medyan 5 | süre ort. 202,9 sn / medyan 13 sn | tekrar oturum %24,98
-- Yorum:
--   * Dağılımlar çok çarpık: ortalama oturum süresi ~3,4 dk görünürken oturumların yarısı 13 saniyenin altında.
--     Bu tür metriklerde medyan raporlanmalı.
--   * Süre = son olay - ilk olay. Tek olaylı oturumlarda süre 0 ölçülür (son sayfada geçen süre ölçülemez).
--   * Sağlama: oturumların %75,02'si kullanıcıların ilk oturumu = 270.154 / 360.129  ✓
SELECT
  ROUND(AVG(events), 1)                                   AS avg_events,
  APPROX_QUANTILES(events, 2)[OFFSET(1)]                  AS median_events,
  ROUND(AVG(session_duration_sec), 1)                     AS avg_duration_sec,
  APPROX_QUANTILES(session_duration_sec, 2)[OFFSET(1)]    AS median_duration_sec,
  ROUND(100 * COUNTIF(session_index > 1) / COUNT(*), 2)   AS pct_repeat_sessions
FROM `ga4-funnel-analytics-515610.ga4_funnel.fct_sessions`;
