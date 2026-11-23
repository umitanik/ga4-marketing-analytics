-- dim_users_checks.sql
-- Amaç : dim_users tablosunun doğru kurulduğunu doğrulamak (veri testleri).
-- Her kontrol ayrı çalıştırıldı; sonuçlar her kontrolün başında.

-- Kontrol 1: Her kullanıcı tam olarak bir satır mı? (benzersizlik testi)
-- Beklenen: row_count = users = 270.154
-- Sonuç   : 270.154 | 270.154  ✓  (JOIN'lerde satır çoğalması riski yok)
SELECT
  COUNT(*)                       AS row_count,
  COUNT(DISTINCT user_pseudo_id) AS users
FROM `ga4-funnel-analytics-515610.ga4_funnel.dim_users`;


-- Kontrol 2: Kanal grubu dağılımı. Toplam artık kullanıcı sayısına eşit mi?
-- Beklenen: users toplamı = 270.154 (ham veride kanal toplamı 333.388 idi)
-- Sonuç   :
--   channel_group  | users   | pct_of_users
--   Organic Search | 101.782 | 37,68
--   Unknown        |  64.719 | 23,96
--   Direct         |  64.112 | 23,73
--   Referral       |  25.250 |  9,35
--   Paid Search    |  14.291 |  5,29
--   Toplam 270.154  ✓
SELECT
  channel_group,
  COUNT(*)                                       AS users,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_users
FROM `ga4-funnel-analytics-515610.ga4_funnel.dim_users`
GROUP BY channel_group
ORDER BY users DESC;


-- Kontrol 3: Yeni kullanıcılar ve kanal bilgisinin kaynağı
-- Beklenen: new_users = 257.314 (first_visit yapan kullanıcı sayısı, bkz. 00_exploration/02)
-- Sonuç   : new 257.314 | returning 12.840 | basis first_visit 257.314 | first_event 12.840 | 14 hafta  ✓
-- Not     : 1 Kasım 2020 pazar. İlk cohort haftası (2020-10-26) sadece 1 günlük, kısmi bir hafta.
--           Son haftaların cohort'ları da daha kısa süre izlenebiliyor. Cohort mart'ında dikkate alınacak.
SELECT
  COUNTIF(is_new_user)                          AS new_users,
  COUNTIF(NOT is_new_user)                      AS returning_users,
  COUNTIF(acquisition_basis = 'first_visit')    AS basis_first_visit,
  COUNTIF(acquisition_basis = 'first_event')    AS basis_first_event,
  COUNT(DISTINCT cohort_week)                   AS cohort_weeks
FROM `ga4-funnel-analytics-515610.ga4_funnel.dim_users`;
