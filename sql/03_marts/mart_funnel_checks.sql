-- mart_funnel_checks.sql
-- Amaç : mart_funnel tablosunu doğrulamak, sırasız (naive) funnel ile karşılaştırmak ve
--        sepet adımındaki tutarsızlığı araştırmak.
-- Her kontrol ayrı çalıştırıldı; sonuçlar her kontrolün başında.

-- Kontrol 1: Genel sıralı funnel ve sırasız funnel ile karşılaştırma
-- Beklenen: users = 270.154 | view_item = 61.252 | sonraki adımlar naive funnel'dan küçük ya da eşit
--
-- Sonuç (v1, add_to_cart ZORUNLU adımken):
--   adım             | sırasız | sıralı v1 | fark
--   add_to_cart      | 12.545  | 12.538    |   -7
--   begin_checkout   |  9.715  |  5.034    | -%48
--   add_payment_info |  5.751  |  3.568    | -%38
--   purchase         |  4.408  |  2.846    | -%35
--   Sepet -> ödeme geçişi %77,4'ten %40,1'e, genel dönüşüm %1,63'ten %1,05'e düştü.
--   Alıcıların %35'i sıralı funnel'a giremedi -> Kontrol 2 ve 3 ile araştırıldı.
--
-- Sonuç (v2, add_to_cart bilgi amaçlı):
--   users 270.154 | view_item 61.252 | add_to_cart 12.538 (bilgi) | begin_checkout 9.629 |
--   add_payment_info 5.700 | purchase 4.377  ✓
--   Adımdan adıma: gelen->ürün %22,67 | ürün->ödemeye geçme %15,72 | ödemeye geçme->ödeme bilgisi %59,20 |
--                  ödeme bilgisi->satın alma %76,79 | genel %1,62
--   Alıcıların %99,3'ü (4.377 / 4.408) sıralı funnel'a giriyor. Elenen 31 kişi adımları sırasız yapmış.
SELECT
  SUM(users)                  AS users,
  SUM(view_item_users)        AS view_item,
  SUM(add_to_cart_users)      AS add_to_cart,
  SUM(begin_checkout_users)   AS begin_checkout,
  SUM(add_payment_info_users) AS add_payment_info,
  SUM(purchase_users)         AS purchase
FROM `ga4-funnel-analytics-515610.ga4_funnel.mart_funnel`;


-- Kontrol 2: Ödemeye geçenler sepete ne zaman eklemiş?
-- Sonuç:
--   checkout_users        9.715
--   checkout_without_cart 4.058  (%41,8)  hiç sepete eklemeden ödemeye geçmiş
--   cart_after_checkout     927  ( %9,5)  önce ödemeye geçmiş, sepete sonra eklemiş
--   cart_before_checkout  4.730  (%48,7)  sırayla yapmış
--   Sağlama: 4.058 + 927 + 4.730 = 9.715  ✓
--   Not: v1'de begin_checkout 5.034 çıkmıştı (4.730'dan 304 fazla). Bu 304 kişi "sonra eklemiş" grubundan:
--        sepetsiz ödemeye geçip sonra sepete ekleyip TEKRAR ödemeye geçmişler.
WITH user_steps AS (
  SELECT
    user_pseudo_id,
    MIN(IF(event_name = 'add_to_cart',    event_ts, NULL)) AS first_cart_ts,
    MIN(IF(event_name = 'begin_checkout', event_ts, NULL)) AS first_checkout_ts
  FROM `ga4-funnel-analytics-515610.ga4_funnel.stg_events`
  WHERE event_name IN ('add_to_cart', 'begin_checkout')
  GROUP BY user_pseudo_id
)
SELECT
  COUNTIF(first_checkout_ts IS NOT NULL)                                        AS checkout_users,
  COUNTIF(first_checkout_ts IS NOT NULL AND first_cart_ts IS NULL)              AS checkout_without_cart,
  COUNTIF(first_checkout_ts IS NOT NULL AND first_cart_ts > first_checkout_ts)  AS cart_after_checkout,
  COUNTIF(first_checkout_ts IS NOT NULL AND first_cart_ts <= first_checkout_ts) AS cart_before_checkout
FROM user_steps;


-- Kontrol 3: Sepetsiz ödemeye geçenler yeni mi, dönen mi? (varsayım testi)
-- Varsayım: "Sepeti 1 Kasım'dan önce doldurdular." Yeni kullanıcılar dönem öncesinde siteye hiç gelmediği için
--           bu varsayım onlar için mümkün değil.
-- Sonuç: yeni 3.348 (%82,5) | dönen 710 (%17,5) | toplam 4.058  ✓
--        -> "dönem öncesi sepet" açıklaması çoğunluk için elendi. Geriye "hemen al" akışı ya da eksik takip kalıyor
--           (bu veriyle ayırt edilemez). Üç açıklama da aynı karara çıkıyor: add_to_cart funnel kapısı yapılmadı (v2).
WITH user_steps AS (
  SELECT
    user_pseudo_id,
    MIN(IF(event_name = 'add_to_cart',    event_ts, NULL)) AS first_cart_ts,
    MIN(IF(event_name = 'begin_checkout', event_ts, NULL)) AS first_checkout_ts
  FROM `ga4-funnel-analytics-515610.ga4_funnel.stg_events`
  WHERE event_name IN ('add_to_cart', 'begin_checkout')
  GROUP BY user_pseudo_id
)
SELECT
  u.is_new_user,
  COUNT(*) AS checkout_without_cart_users
FROM user_steps AS s
JOIN `ga4-funnel-analytics-515610.ga4_funnel.dim_users` AS u
  ON s.user_pseudo_id = u.user_pseudo_id
WHERE s.first_checkout_ts IS NOT NULL
  AND s.first_cart_ts IS NULL
GROUP BY u.is_new_user;


-- Analiz 1: Kanala göre funnel (iş sorusu 1)
-- Not: Oranlar SUM(pay) / SUM(payda) ile hesaplanır, satır oranlarının ortalaması alınmaz.
-- Sonuç:
--   channel        | users   | visit>view | view>checkout | checkout>payment | payment>purchase | overall
--   Unknown        |  64.719 | 23,45      | 16,58         | 61,01            | 78,37            | 1,86
--   Referral       |  25.250 | 22,81      | 15,75         | 60,09            | 75,05            | 1,62
--   Direct         |  64.112 | 22,61      | 15,70         | 58,26            | 75,79            | 1,57
--   Paid Search    |  14.291 | 21,84      | 14,83         | 60,69            | 77,58            | 1,53
--   Organic Search | 101.782 | 22,30      | 15,28         | 58,06            | 76,60            | 1,52
-- Yorum:
--   * Kanallar her adımda birbirine çok yakın (genel dönüşüm %1,52 – %1,86). Funnel'ın şekli kanala bağlı değil:
--     sızıntılar (ürün sayfası, ödeme bilgisi) site genelinde.
--   * Gerçek verilerde kanallar genelde belirgin şekilde ayrışır. Bu kadar benzerlik, anonimleştirmenin kanal
--     etiketlerini kısmen bulanıklaştırmış olabileceğini düşündürüyor (bkz. not 5: kullanıcıların %15,6'sında
--     birden fazla kanal). Kanal farkları temkinli yorumlanmalı.
--   * Paid Search (%1,53) ile Organic Search (%1,52) neredeyse aynı -> 6. adımda istatistiksel test.
--   * Unknown en yüksek. Olası açıklama: self-referral (ödeme sayfasından geri dönüşler) bu grupta. Unknown
--     üzerinde aksiyon alınamayacağı için ayrıca araştırılmadı.
SELECT
  channel_group,
  SUM(users)                                                                AS users,
  ROUND(100 * SUM(view_item_users)        / SUM(users), 2)                  AS visit_to_view,
  ROUND(100 * SUM(begin_checkout_users)   / SUM(view_item_users), 2)        AS view_to_checkout,
  ROUND(100 * SUM(add_payment_info_users) / SUM(begin_checkout_users), 2)   AS checkout_to_payment,
  ROUND(100 * SUM(purchase_users)         / SUM(add_payment_info_users), 2) AS payment_to_purchase,
  ROUND(100 * SUM(purchase_users)         / SUM(users), 2)                  AS overall_conversion
FROM `ga4-funnel-analytics-515610.ga4_funnel.mart_funnel`
GROUP BY channel_group
ORDER BY overall_conversion DESC;


-- Analiz 2: Cihaza göre funnel (iş sorusu 1)
-- Sonuç:
--   device  | users   | visit>view | view>checkout | checkout>payment | payment>purchase | overall
--   desktop | 156.905 | 22,75      | 15,57         | 58,98            | 76,14            | 1,59
--   mobile  | 107.175 | 22,54      | 15,96         | 59,45            | 77,80            | 1,66
--   tablet  |   6.074 | 22,97      | 15,34         | 60,28            | 75,19            | 1,60
--   Sağlama: 156.905 + 107.175 + 6.074 = 270.154  ✓
-- Yorum:
--   * Cihazlar da her adımda neredeyse aynı. Gerçek verilerde mobil genelde masaüstünden belirgin şekilde
--     düşük dönüşür (özellikle ödeme adımında); burada mobil biraz daha yüksek.
--   * Hem kanal hem cihaz kırılımının bu kadar düz çıkması, anonimleştirmenin kullanıcı özelliklerini
--     (kanal, cihaz) kısmen karıştırmış olabileceğine işaret ediyor. Olay sıraları (funnel) ve tarihler
--     korunmuş görünüyor. Segment karşılaştırmaları temkinli yorumlanmalı; genel funnel bulguları daha güvenilir.
SELECT
  device_category,
  SUM(users)                                                                AS users,
  ROUND(100 * SUM(view_item_users)        / SUM(users), 2)                  AS visit_to_view,
  ROUND(100 * SUM(begin_checkout_users)   / SUM(view_item_users), 2)        AS view_to_checkout,
  ROUND(100 * SUM(add_payment_info_users) / SUM(begin_checkout_users), 2)   AS checkout_to_payment,
  ROUND(100 * SUM(purchase_users)         / SUM(add_payment_info_users), 2) AS payment_to_purchase,
  ROUND(100 * SUM(purchase_users)         / SUM(users), 2)                  AS overall_conversion
FROM `ga4-funnel-analytics-515610.ga4_funnel.mart_funnel`
GROUP BY device_category
ORDER BY users DESC;
