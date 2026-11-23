-- mart_daily_kpis_checks.sql
-- Amaç : mart_daily_kpis tablosunu doğrulamak ve zaman içindeki değişimi analiz etmek (iş sorusu 4).
-- Her sorguyu ayrı çalıştırın; sonuçlar her sorgunun başına not edilecek.

-- Kontrol 1: Toplanabilir metrikler core tablolarla tutuyor mu?
-- Beklenen: days 92 | sessions 360.129 | new_users 257.314 | purchase_sessions 4.837 |
--           orders 5.283 | revenue_usd 338.153
-- Not: active_users ve purchasers günler arasında toplanamaz; bu yüzden burada yoklar.
-- Sonuç: 92 | 360.129 | 257.314 | 4.837 | 5.283 | 338.153  ✓
SELECT
  COUNT(DISTINCT date)       AS days,
  SUM(sessions)              AS sessions,
  SUM(new_users)             AS new_users,
  SUM(purchase_sessions)     AS purchase_sessions,
  SUM(orders)                AS orders,
  ROUND(SUM(revenue_usd), 2) AS revenue_usd
FROM `ga4-funnel-analytics-515610.ga4_funnel.mart_daily_kpis`;


-- Analiz 1: Haftalık trend (iş sorusu 4)
-- Not: Haftalar pazartesi başlangıçlı. İlk hafta (2020-10-26) sadece 1 Kasım'ı içeriyor.
-- Sonuç:
--   week       | days | sessions | new    | view>chk | sess conv | orders | AOV   | revenue
--   2020-10-26 | 1    |  2.625   |  1.946 | 17,69    | 0,50      |  14    | 55,21 |    773
--   2020-11-02 | 7    | 24.991   | 16.500 | 15,99    | 1,00      | 260    | 79,20 | 20.592
--   2020-11-09 | 7    | 22.508   | 14.590 | 18,72    | 1,52      | 359    | 65,37 | 23.467
--   2020-11-16 | 7    | 25.914   | 16.906 | 15,80    | 1,44      | 403    | 66,05 | 26.619
--   2020-11-23 | 7    | 27.780   | 18.734 | 19,65    | 1,85      | 559    | 71,68 | 40.070  (Black Friday)
--   2020-11-30 | 7    | 31.088   | 21.195 | 18,23    | 1,90      | 638    | 66,82 | 42.631  (Cyber Monday)
--   2020-12-07 | 7    | 38.729   | 27.558 | 19,24    | 1,99      | 855    | 69,29 | 59.244  (zirve)
--   2020-12-14 | 7    | 33.411   | 24.221 | 14,34    | 1,63      | 674    | 68,64 | 46.266
--   2020-12-21 | 7    | 22.083   | 17.013 | 10,11    | 1,05      | 253    | 57,19 | 14.470  (Noel)
--   2020-12-28 | 7    | 20.444   | 16.300 |  8,39    | 0,67      | 144    | 69,60 | 10.022  (yılbaşı)
--   2021-01-04 | 7    | 29.029   | 22.458 |  7,78    | 0,55      | 167    | 55,62 |  9.288  (dip)
--   2021-01-11 | 7    | 27.707   | 21.008 |  9,46    | 0,81      | 248    | 51,88 | 12.865
--   2021-01-18 | 7    | 27.478   | 20.220 | 10,55    | 1,36      | 388    | 67,78 | 26.300
--   2021-01-25 | 7    | 26.342   | 18.665 |  9,37    | 1,18      | 321    | 17,28 |  5.546  <- ANOMALİ
--   Sağlama: Σ orders = 5.283, Σ revenue = 338.153  ✓
-- Yorum:
--   * Sezon zirvesi: oturum dönüşümü Kasım başında %1,00'den 7 Aralık haftasında %1,99'a (2 kat) çıktı.
--     Haftalık gelir zirvede 59.244 USD.
--   * Aralık ortasından itibaren kırılma: 4 Ocak haftasında dönüşüm %0,55 (zirveden -%72), gelir -%84.
--     Ama trafik sadece -%25 (38.729 -> 29.029). Ocak'ta trafik geri geldi, dönüşüm gelmedi.
--   * Kırılma funnel'da ÜRÜN -> ÖDEMEYE GEÇME adımında: %19'dan %8'e düştü ve Ocak sonunda bile ~%10'da kaldı
--     (Kasım ortalaması ~%17).
--   * ANOMALİ: 25 Ocak haftasında 321 sipariş ama ortalama sipariş tutarı 17,28 USD (normalde ~65).
--     Gelir metriğini etkilediği için araştırılıyor -> Analiz 2.
SELECT
  DATE_TRUNC(date, WEEK(MONDAY))                                              AS week,
  COUNT(DISTINCT date)                                                        AS days,
  SUM(sessions)                                                               AS sessions,
  SUM(new_users)                                                              AS new_users,
  ROUND(100 * SUM(sessions_with_checkout) / SUM(sessions_with_item_view), 2)  AS view_to_checkout,
  ROUND(100 * SUM(purchase_sessions) / SUM(sessions), 2)                      AS session_conversion,
  SUM(orders)                                                                 AS orders,
  ROUND(SUM(revenue_usd) / SUM(orders), 2)                                    AS avg_order_value,
  ROUND(SUM(revenue_usd), 0)                                                  AS revenue_usd
FROM `ga4-funnel-analytics-515610.ga4_funnel.mart_daily_kpis`
GROUP BY week
ORDER BY week;


-- Analiz 2: Son iki haftada sipariş tutarı anomalisi (günlük)
-- Sonuç:
--   date       | orders | zero_rev | AOV   | median
--   2021-01-18 | 18     |  1       | 65,67 | 38
--   2021-01-19 | 48     |  3       | 78,25 | 44
--   2021-01-20 | 95     | 12       | 70,13 | 81
--   2021-01-21 | 52     |  2       | 80,88 | 79
--   2021-01-22 | 97     |  6       | 55,80 | 39
--   2021-01-23 | 43     |  2       | 63,88 | 38
--   2021-01-24 | 35     |  2       | 66,69 | 48
--   2021-01-25 | 61     |  8       | 54,97 | 44
--   2021-01-26 | 53     | 31 (%58) | 23,75 |  0   <- kırılma
--   2021-01-27 | 53     | 41 (%77) |  8,62 |  0
--   2021-01-28 | 56     | 51 (%91) |  2,29 |  0
--   2021-01-29 | 51     | 45 (%88) |  3,73 |  0
--   2021-01-30 | 29     | 24 (%83) |  5,48 |  0
--   2021-01-31 | 18     | 18 (%100)|  0,00 |  0
-- Yorum:
--   * 26 Ocak'tan itibaren siparişler kaydediliyor ama gelir 0 yazılıyor: GELİR TAKİBİ BOZULMUŞ.
--     Sipariş sayıları normal (günde 50 civarı), sadece tutarlar kayıp.
--   * 26-31 Ocak: 260 sipariş, 210'u sıfır gelirli. Normal sıfır oranı (~%5-10) düşülürse ~190 siparişin
--     geliri kayıp; ~65 USD ortalamayla ~12.000 USD, toplam gelirin ~%3,5'i.
--   * Ders: fct_orders kontrol 1 "gelirsiz sipariş = 0" demişti, ama sadece NULL'u kontrol ediyordu.
--     Gelir NULL değil 0 olarak kaydedilmiş. Veri testleri hem NULL'u hem 0'ı (ve negatifleri) kontrol etmeli.
--   * 26 Ocak öncesinde de her gün birkaç sıfır gelirli sipariş var -> dönem geneli: Analiz 3.


-- Analiz 3: Sıfır gelirli siparişlerin dönem boyunca payı ve sıfırlar hariç ortalama sipariş tutarı
-- Not: AVG NULL'ları atlar; IF(revenue_usd > 0, revenue_usd, NULL) sıfırları hesaptan çıkarır.
-- Sonuç:
--   week       | orders | zero | %zero | aov_all | aov_excl_zero
--   2020-10-26 |  14    |   0  |  0,0  | 55,21   | 55,21
--   2020-11-02 | 260    |   0  |  0,0  | 79,20   | 79,20
--   2020-11-09 | 359    |   2  |  0,6  | 65,37   | 65,73
--   2020-11-16 | 403    |  22  |  5,5  | 66,05   | 69,87
--   2020-11-23 | 559    |  26  |  4,7  | 71,68   | 75,18
--   2020-11-30 | 638    |  28  |  4,4  | 66,82   | 69,89
--   2020-12-07 | 855    |  32  |  3,7  | 69,29   | 71,99
--   2020-12-14 | 674    |  15  |  2,2  | 68,64   | 70,21
--   2020-12-21 | 253    |   8  |  3,2  | 57,19   | 59,06
--   2020-12-28 | 144    |   5  |  3,5  | 69,60   | 72,10
--   2021-01-04 | 167    |   8  |  4,8  | 55,62   | 58,42
--   2021-01-11 | 248    |  19  |  7,7  | 51,87   | 56,18
--   2021-01-18 | 388    |  28  |  7,2  | 67,78   | 73,06
--   2021-01-25 | 321    | 218  | 67,9  | 17,28   | 53,84   <- takip arızası (26 Ocak'tan itibaren)
--   Toplam: 411 sıfır gelirli sipariş (%7,8). 26 Ocak öncesi: 201 / 5.023 = %4,0 (taban seviye).
-- Yorum:
--   * Taban seviye: Kasım ortasından itibaren siparişlerin ~%2-8'i sıfır gelirli. Bedava ürün / %100 indirim
--     gibi gerçek sıfırlar olabilir; bu veriyle ayırt edilemez. Dönem boyunca sabit, tek seferlik bir arıza değil.
--   * 26-31 Ocak: sıfır oranı %80'in üstünde -> gelir takibi arızası. Taban seviye (~%4) düşülünce ~200 siparişin
--     geliri kayıp; ~69 USD ile ~13.800 USD, toplam gelirin ~%4'ü.
--   * Sıfırlar hariç ortalama sipariş tutarı (dönem geneli): 338.153 / 4.872 = 69,41 USD (sıfırlar dahil 64,01).
-- Karar (docs/data_quality.md not 10):
--   * mart_daily_kpis'e is_revenue_tracked bayrağı eklendi (tarih < 2021-01-26). Gelir trendlerinde ve gelir
--     bazlı metriklerde 26-31 Ocak dışarıda bırakılır ya da işaretlenir; sipariş sayıları ve dönüşüm kullanılmaya devam eder.
--   * Ortalama sipariş tutarı gelir > 0 olan siparişler üzerinden raporlanır.
--   * Kanal bazlı gelir metrikleri (mart_channel_quality) ~%4 düşük; arızanın kanallara eşit dağıldığı varsayımıyla
--     kanal karşılaştırmaları geçerliliğini koruyor.
SELECT
  DATE_TRUNC(order_date, WEEK(MONDAY))                    AS week,
  COUNT(*)                                                AS orders,
  COUNTIF(revenue_usd = 0)                                AS zero_revenue_orders,
  ROUND(100 * COUNTIF(revenue_usd = 0) / COUNT(*), 1)     AS pct_zero,
  ROUND(AVG(revenue_usd), 2)                              AS aov_all,
  ROUND(AVG(IF(revenue_usd > 0, revenue_usd, NULL)), 2)   AS aov_excl_zero
FROM `ga4-funnel-analytics-515610.ga4_funnel.fct_orders`
GROUP BY week
ORDER BY week;
SELECT
  order_date,
  COUNT(*)                                      AS orders,
  COUNTIF(revenue_usd = 0)                      AS zero_revenue_orders,
  ROUND(AVG(revenue_usd), 2)                    AS avg_order_value,
  APPROX_QUANTILES(revenue_usd, 2)[OFFSET(1)]   AS median_order_value
FROM `ga4-funnel-analytics-515610.ga4_funnel.fct_orders`
WHERE order_date >= DATE '2021-01-18'
GROUP BY order_date
ORDER BY order_date;
