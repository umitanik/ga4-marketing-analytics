-- mart_channel_quality_checks.sql
-- Amaç : mart_channel_quality tablosunu doğrulamak ve kanal kalitesini analiz etmek.
-- Her sorguyu ayrı çalıştırın; sonuçlar her sorgunun başına not edilecek.

-- Kontrol 1: Toplamlar core tablolarla tutuyor mu?
-- Beklenen: users 270.154 | new_users 257.314 | sessions 360.129 | purchasers 4.408 |
--           repeat_purchasers 528 | orders 5.283 | revenue_usd 338.153
-- Sonuç   : hepsi tuttu  ✓  | returning_visitors 47.364 (kullanıcıların %17,5'i en az iki kez gelmiş)
SELECT
  SUM(users)              AS users,
  SUM(new_users)          AS new_users,
  SUM(sessions)           AS sessions,
  SUM(returning_visitors) AS returning_visitors,
  SUM(purchasers)         AS purchasers,
  SUM(repeat_purchasers)  AS repeat_purchasers,
  SUM(orders)             AS orders,
  ROUND(SUM(revenue_usd), 2) AS revenue_usd
FROM `ga4-funnel-analytics-515610.ga4_funnel.mart_channel_quality`;


-- Analiz 1: Kanal kalitesi (iş sorusu 2)
-- Not: Oranlar SUM / SUM ile hesaplanır.
-- Sonuç:
--   channel        | users   | %users | %revenue | sess/user | return% | conv% | AOV   | repeat% | rev/user
--   Unknown        |  64.719 | 23,96  | 28,52    | 1,35      | 18,29   | 1,88  | 65,69 | 12,69   | 1,49
--   Referral       |  25.250 |  9,35  |  9,30    | 1,34      | 17,64   | 1,64  | 66,22 | 11,14   | 1,25
--   Direct         |  64.112 | 23,73  | 22,79    | 1,34      | 17,58   | 1,57  | 63,26 | 13,11   | 1,20
--   Paid Search    |  14.291 |  5,29  |  5,00    | 1,31      | 17,12   | 1,53  | 67,95 | 10,50   | 1,18
--   Organic Search | 101.782 | 37,68  | 34,39    | 1,32      | 17,06   | 1,53  | 62,09 | 11,13   | 1,14
--   Genel kullanıcı başına gelir: 338.153 / 270.154 = 1,25 USD
-- Yorum:
--   * En çok kullanıcıyı getiren kanal (Organic, %37,7) kullanıcı başına EN AZ geliri getiriyor (1,14 USD,
--     ortalamanın %9 altı) ve gelir payı kullanıcı payından 3,3 puan düşük. Cevap: hayır, aynı değil.
--     Ama farklar küçük.
--   * Paid Search: en yüksek ortalama sipariş tutarı (67,95) ama en düşük tekrar alım (%10,5).
--     DİKKAT: Paid Search'te sadece ~219 alıcı var. %10,5 tekrar alımın %95 güven aralığı kabaca %6 – %15;
--     diğer kanallarla örtüşüyor. Bu farklar istatistiksel olarak güvenilir değil.
--   * Bütün metrikler kanallar arasında dar bir bantta (geri dönüş %17,1 – %18,3, dönüşüm %1,53 – %1,88).
--     Segment bulanıklığı uyarısı (mart_funnel_checks) burada da geçerli.
--   * Unknown yine en yüksek (self-referral hipotezi), aksiyon alınamaz.
SELECT
  channel_group,
  SUM(users)                                                        AS users,
  ROUND(100 * SUM(users) / SUM(SUM(users)) OVER (), 2)              AS pct_of_users,
  ROUND(100 * SUM(revenue_usd) / SUM(SUM(revenue_usd)) OVER (), 2)  AS pct_of_revenue,
  ROUND(SUM(sessions) / SUM(users), 2)                              AS sessions_per_user,
  ROUND(100 * SUM(returning_visitors) / SUM(users), 2)              AS return_visit_rate,
  ROUND(100 * SUM(purchasers) / SUM(users), 2)                      AS conversion_rate,
  ROUND(SUM(revenue_usd) / SUM(orders), 2)                          AS avg_order_value,
  ROUND(100 * SUM(repeat_purchasers) / SUM(purchasers), 2)          AS repeat_purchase_rate,
  ROUND(SUM(revenue_usd) / SUM(users), 2)                           AS revenue_per_user
FROM `ga4-funnel-analytics-515610.ga4_funnel.mart_channel_quality`
GROUP BY channel_group
ORDER BY revenue_per_user DESC;
