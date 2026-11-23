-- mart_first_session_checks.sql
-- Amaç : Modelleme veri setini doğrulamak.
-- v2   : purchased_first_session kolonu eklendi (sızıntı kontrolü için, notebook 2.7). Kontrol 2 bu kolonla ilgili.

-- Kontrol 1: Satır sayısı, benzersizlik ve hedef oranı
-- Beklenen: row_count = users ≈ 257.314 - 18.665 (25-31 Ocak cohort'u) = 238.649
--           purchase_rate_7d ~%1-2 (dengesiz sınıf: alıcılar çok az)
-- Sonuç: 238.649 satır = 238.649 kullanıcı ✓ | 2.733 alıcı (%1,15, 7 gün içinde) | ilk oturumda sepete ekleme %3,41
-- Not  : Dengesiz sınıf (%1,15 pozitif) ama 2.733 pozitif örnek ~15 değişkenli bir lojistik regresyon için yeterli
--        (kaba kural: değişken başına en az 10-20 pozitif örnek).
SELECT
  COUNT(*)                                          AS row_count,
  COUNT(DISTINCT user_pseudo_id)                    AS users,
  COUNTIF(purchased_7d)                             AS purchasers_7d,
  ROUND(100 * COUNTIF(purchased_7d) / COUNT(*), 2)  AS purchase_rate_7d,
  ROUND(100 * COUNTIF(added_to_cart) / COUNT(*), 2) AS add_to_cart_rate
FROM `ga4-funnel-analytics-515610.ga4_funnel.mart_first_session`;


-- Kontrol 2 (v2): İlk oturumda satın alanların payı ve tutarlılık
-- Neden : Lojistik regresyonun açıklama gücü şüpheli derecede yüksekti (pseudo R² 0,375, AUC 0,937).
--         İlk oturumda satın alanların süresi ve ürün görüntülemesi satın alma sürecinin kendisini de içerdiği için
--         hedef özelliklere sızıyor olabilir (target leakage).
-- Beklenen: İlk oturumda satın alan herkes purchased_7d = TRUE olmalı (inconsistent = 0).
-- Sonuç : 2.733 alıcının 1.641'i (%60,0) satın almayı ilk oturumda yapmış, 1.092'si sonradan.
--         İlk oturumda alanlar çıkarılınca pseudo R² 0,193, AUC 0,873 (notebook 2.7).
--         ✗ inconsistent = 1 (beklenen 0): 1 kullanıcı ilk oturumda satın almış ama purchased_7d = FALSE. Nedeni: Kontrol 3.
--         Nasıl yakalandı: "Sonradan alan" sayısı önce çıkarmayla hesaplanmıştı (2.733 − 1.642 = 1.091). Alt örneklemdeki
--         alıcılar doğrudan sayılınca (notebook 2.8) 1.092 çıktı. Ders: aynı sayıyı iki farklı yoldan hesapla (sağlama).
--         Etkisi: 238.649 kullanıcıda 1 kişi. Bu kullanıcı ikinci modele zaten girmiyor (ilk oturumda almış).
SELECT
  COUNTIF(purchased_7d)                                   AS purchasers_7d,
  COUNTIF(purchased_first_session)                        AS first_session_purchasers,
  ROUND(100 * COUNTIF(purchased_first_session)
            / COUNTIF(purchased_7d), 1)                   AS pct_first_session,
  COUNTIF(purchased_first_session AND NOT purchased_7d)   AS inconsistent
FROM `ga4-funnel-analytics-515610.ga4_funnel.mart_first_session`;


-- Kontrol 3: Tutarsız kullanıcının nedeni
-- Hipotez: Kullanıcının ilk oturumu, first_visit olayının tarihinden önce (first_visit sonraki bir oturumda kaydedilmiş).
--          O zaman sipariş tarihi < first_visit_date olur ve 7 günlük pencere koşulu (sipariş >= ilk ziyaret) sağlanmaz.
-- Sonuç : 1 satır ✓ hipotez doğrulandı. İlk oturum ve sipariş 10 Kasım 2020 (oturum açıldıktan ~3,5 dk sonra sipariş),
--         first_visit olayı ise 4 gün sonra, 14 Kasım'da kaydedilmiş. Kullanıcı first_visit'ten önce sitede ve alışveriş yapmış:
--         bir takip kenar durumu (first_visit olayı ilk ziyarette tetiklenmemiş ya da geç kaydedilmiş).
--         Etkisi: Bu tür kullanıcıların model özellikleri (session_index = 1) first_visit_date'ten önceki bir oturumdan geliyor.
--         Retention etkilenmiyor: first_visit'ten önceki 1-6 günlük oturumlar DIV(negatif, 7) = 0 ile 0. haftaya düşüyor,
--         7+ gün öncekiler negatif hafta olup 0-13 ızgarasına girmiyor. Kaç kullanıcıyı etkilediği: Kontrol 4.
SELECT
  m.user_pseudo_id,
  m.first_visit_date,
  s.session_date        AS first_session_date,
  o.first_order_date,
  s.session_start_ts,
  o.first_order_ts
FROM `ga4-funnel-analytics-515610.ga4_funnel.mart_first_session` AS m
JOIN `ga4-funnel-analytics-515610.ga4_funnel.fct_sessions` AS s
  ON  m.user_pseudo_id = s.user_pseudo_id
  AND s.session_index = 1
JOIN (
  SELECT
    user_pseudo_id,
    MIN(order_date) AS first_order_date,
    MIN(order_ts)   AS first_order_ts
  FROM `ga4-funnel-analytics-515610.ga4_funnel.fct_orders`
  GROUP BY user_pseudo_id
) AS o
  ON m.user_pseudo_id = o.user_pseudo_id
WHERE m.purchased_first_session
  AND NOT m.purchased_7d;


-- Kontrol 4: first_visit olayından ÖNCE görülen "yeni" kullanıcı sayısı (Kontrol 3'teki durum ne kadar yaygın?)
-- Neden: Kontrol 3'teki kullanıcı sadece ilk oturumda satın aldığı için görünür oldu. Satın almayan benzer kullanıcılar
--        da olabilir. Az ise not alıp geçilir; çoksa ilk ziyaret tanımı (first_visit_date) gözden geçirilmeli.
-- Sonuç : 257.314 yeni kullanıcının 15'i (%0,006) first_visit'ten önce görülmüş. En büyük fark 77 gün.
-- Karar : Dokunulmadı. Etkisi ihmal edilebilir; tanımı değiştirmek (ör. ilk görülme tarihini ilk ziyaret saymak) cohort
--         haftalarını ve bütün mart tablolarını yeniden kurmayı gerektirirdi. Veri kalitesi notu 11 olarak kaydedildi.
SELECT
  COUNTIF(is_new_user)                                                            AS new_users,
  COUNTIF(is_new_user AND first_seen_date < first_visit_date)                     AS seen_before_first_visit,
  ROUND(100 * COUNTIF(is_new_user AND first_seen_date < first_visit_date)
            / COUNTIF(is_new_user), 3)                                            AS pct,
  MAX(IF(is_new_user, DATE_DIFF(first_visit_date, first_seen_date, DAY), NULL))   AS max_gap_days
FROM `ga4-funnel-analytics-515610.ga4_funnel.dim_users`;
