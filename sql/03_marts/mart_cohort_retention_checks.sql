-- mart_cohort_retention_checks.sql
-- Amaç : mart_cohort_retention tablosunu doğrulamak ve retention'ı analiz etmek.
-- Her sorguyu ayrı çalıştırın; sonuçlar her sorgunun başına not edilecek.

-- Kontrol 1: 0. hafta
-- Beklenen: cohort_users = 257.314 (yeni kullanıcı sayısı)
--           active_users 0. haftada cohort_users'a eşit ya da çok yakın (herkes ilk haftasında aktif)
-- Sonuç   : 257.314 | 257.314 | 14 cohort  ✓
-- Not     : WHERE week_number = 0 şart; cohort_size her hafta satırında tekrar ediyor.
SELECT
  SUM(cohort_size)  AS cohort_users,
  SUM(active_users) AS active_users,
  COUNT(DISTINCT cohort_week) AS cohorts
FROM `ga4-funnel-analytics-515610.ga4_funnel.mart_cohort_retention`
WHERE week_number = 0;


-- Analiz 1: Genel retention eğrisi (sadece tam izlenen haftalar, kısmi ilk cohort hariç)
-- Not: Her hafta için sadece o haftayı tam izlenebilen cohort'lar dahil; ileri haftalarda cohort sayısı azalır.
-- Sonuç:
--   week | cohorts | cohort_users | active | retention
--   0    | 12      | 236.703      | 236.703| 100,00
--   1    | 11      | 216.483      |  4.625 |   2,14
--   2    | 10      | 195.475      |  2.480 |   1,27
--   3    |  9      | 173.017      |  1.733 |   1,00
--   4    |  8      | 156.717      |  1.273 |   0,81
--   5    |  7      | 139.704      |    756 |   0,54
--   6    |  6      | 115.483      |    442 |   0,38
--   7    |  5      |  87.925      |    270 |   0,31
--   8    |  4      |  66.730      |    177 |   0,27
--   9    |  3      |  47.996      |    138 |   0,29
--   10   |  2      |  31.090      |     73 |   0,23
--   11   |  1      |  16.500      |     23 |   0,14
-- Yorum:
--   * 2. haftasında (week 1) geri gelen yeni kullanıcı sadece %2,1. 4 hafta sonra %0,8.
--   * Eğri 6-7. haftadan sonra ~%0,3 civarında yataylaşıyor: küçük bir sadık çekirdek. Ama bu haftalar
--     5 ve daha az cohort'a dayanıyor ve Aralık tatil dönemine denk geliyor, daha az güvenilir.
--   * Kullanıcıların %17,5'i dönem içinde en az iki kez geliyordu (mart_channel_quality). İkinci haftadaki
--     %2,1 ile karşılaştırınca: geri dönüşlerin büyük kısmı İLK 7 GÜN içinde oluyor. Bir kısmı aynı gün
--     içindeki ikinci oturum (30 dk hareketsizlikten sonra yeni oturum) olabilir.
--   * Bir merch mağazası için düşük retention beklenen bir şey (seyrek alışveriş). Yatırım uygulaması
--     benchmark'ları çok daha yüksektir, karşılaştırılmamalı.
--   * Her haftanın oranı farklı cohort karışımına dayanıyor (ileri haftalarda sadece erken cohort'lar).


-- Analiz 2: Cohort tablosu (cohort × hafta, pivot). İş sorusu 3 ve 4 (dönemsel değişim).
-- Teknik: Koşullu toplama ile pivot: SUM(IF(week_number = k, ..., 0)). NULLIF sıfıra bölmeyi önler.
-- Sonuç:
--   cohort_week | users  | w1    | w2    | w4
--   2020-10-26  |  1.946 | 1,64  | 1,13  | 0,51   (kısmi: sadece 1 Kasım)
--   2020-11-02  | 16.500 | 2,42  | 1,72  | 1,05
--   2020-11-09  | 14.590 | 3,56  | 1,94  | 1,36
--   2020-11-16  | 16.906 | 3,40  | 2,25  | 1,06
--   2020-11-23  | 18.734 | 2,75  | 1,71  | 0,52   (Black Friday haftası)
--   2020-11-30  | 21.195 | 2,84  | 1,55  | 0,56   (Cyber Monday haftası)
--   2020-12-07  | 27.558 | 1,61  | 0,65  | 0,89   (en büyük cohort)
--   2020-12-14  | 24.221 | 1,35  | 0,93  | 0,75
--   2020-12-21  | 17.013 | 1,38  | 0,97  | 0,48
--   2020-12-28  | 16.300 | 1,28  | 0,66  | –
--   2021-01-04  | 22.458 | 1,74  | 0,93  | –
--   2021-01-11  | 21.008 | 1,96  | –     | –
--   2021-01-18  | 20.220 | –     | –     | –
--   2021-01-25  | 18.665 | –     | –     | –
--   Sağlama: Σ cohort_users = 257.314  ✓
-- Yorum:
--   * Hacim ve kalite ters yönde: Kasım ortası cohort'ları (02-16 Kasım) haftada ~16.000 kullanıcı,
--     ağırlıklı w1 retention %3,11. Aralık cohort'ları (07-28 Aralık) haftada ~21.300 kullanıcı (+%33),
--     ağırlıklı w1 retention %1,43 (yarıdan az). Tatil sezonu daha çok ama daha az bağlı kullanıcı getiriyor.
--   * Cohort etkisi mi, takvim etkisi mi? Aralık cohort'larının 1. haftası Noel'e denk geliyor; düşüş kısmen
--     takvimden olabilir. Ama 7 Aralık cohort'unun 1. haftası (14-20 Aralık) yoğun bir alışveriş haftası ve
--     w1 yine %1,61 -> kullanıcı kalitesi etkisi de var.
--   * Takvim etkisinin kanıtı: 7 Aralık cohort'unda w4 (%0,89, Ocak başı) > w2 (%0,65, Noel haftası).
--     Retention eğrisi tek yönlü düşmüyor; geri dönüşler takvime bağlı. 9 Kasım cohort'unun w4'ü (%1,36)
--     Aralık başındaki alışveriş haftasına denk geliyor.
--   * Hacim: 7 Aralık haftası zirve (27.558), Noel ve yılbaşı haftalarında düşüş (~16-17 bin), Ocak'ta toparlanma.
SELECT
  cohort_week,
  SUM(IF(week_number = 0, cohort_size, 0)) AS cohort_users,
  ROUND(100 * SUM(IF(week_number = 1 AND is_complete_week, active_users, 0))
            / NULLIF(SUM(IF(week_number = 1 AND is_complete_week, cohort_size, 0)), 0), 2) AS w1_retention,
  ROUND(100 * SUM(IF(week_number = 2 AND is_complete_week, active_users, 0))
            / NULLIF(SUM(IF(week_number = 2 AND is_complete_week, cohort_size, 0)), 0), 2) AS w2_retention,
  ROUND(100 * SUM(IF(week_number = 4 AND is_complete_week, active_users, 0))
            / NULLIF(SUM(IF(week_number = 4 AND is_complete_week, cohort_size, 0)), 0), 2) AS w4_retention
FROM `ga4-funnel-analytics-515610.ga4_funnel.mart_cohort_retention`
GROUP BY cohort_week
ORDER BY cohort_week;
SELECT
  week_number,
  COUNT(DISTINCT cohort_week)                            AS cohorts,
  SUM(cohort_size)                                       AS cohort_users,
  SUM(active_users)                                      AS active_users,
  ROUND(100 * SUM(active_users) / SUM(cohort_size), 2)   AS retention_pct
FROM `ga4-funnel-analytics-515610.ga4_funnel.mart_cohort_retention`
WHERE is_complete_week
  AND NOT is_partial_cohort
GROUP BY week_number
ORDER BY week_number;
