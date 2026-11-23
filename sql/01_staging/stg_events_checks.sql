-- stg_events_checks.sql
-- Amaç : stg_events tablosunun doğru kurulduğunu doğrulamak (veri testleri).
-- Her kontrol ayrı çalıştırıldı; sonuçlar her kontrolün başında.

-- Kontrol 1: Satır ve kullanıcı sayısı ham veriyle aynı mı?
-- Beklenen: row_count = 4.295.584, users = 270.154 (bkz. 00_exploration/01_dataset_overview.sql)
-- Sonuç   : 4.295.584 | 270.154  ✓  (veri kaybı ya da çoğalma yok)
-- Not     : "rows" BigQuery'de ayrılmış (reserved) bir kelime, takma ad olarak kullanılamaz.
SELECT
  COUNT(*)                       AS row_count,
  COUNT(DISTINCT user_pseudo_id) AS users
FROM `ga4-funnel-analytics-515610.ga4_funnel.stg_events`;


-- Kontrol 2: Tarih aralığı ve zaman dönüşümü doğru mu?
-- Beklenen: 2020-11-01 – 2021-01-31; event_ts tarihleri event_date ile uyumlu
-- Sonuç   : event_date 2020-11-01 – 2021-01-31 | event_ts 2020-11-01 – 2021-01-31  ✓
SELECT
  MIN(event_date)     AS first_day,
  MAX(event_date)     AS last_day,
  MIN(DATE(event_ts)) AS first_ts_day,
  MAX(DATE(event_ts)) AS last_ts_day
FROM `ga4-funnel-analytics-515610.ga4_funnel.stg_events`;


-- Kontrol 3: Oturum kimliği ne kadar dolu, kaç oturum var?
-- Beklenen: oturum sayısı session_start olay sayısına (354.970) yakın
-- Sonuç   : oturumsuz olay 0 (%0,0) | 360.129 oturum  ✓
--           session_start'tan 5.159 fazla (~%1,4) -> bkz. docs/data_quality.md not 7
SELECT
  COUNTIF(ga_session_id IS NULL)                            AS events_without_session,
  ROUND(100 * COUNTIF(ga_session_id IS NULL) / COUNT(*), 2) AS pct_without_session,
  COUNT(DISTINCT session_id)                                AS sessions
FROM `ga4-funnel-analytics-515610.ga4_funnel.stg_events`;


-- Kontrol 4: Satın alma ve gelir bilgisi geldi mi?
-- Beklenen: purchase_events = 5.692, purchasers = 4.419
-- Sonuç   : 5.692 olay | 4.419 alıcı | 4.452 benzersiz transaction_id | 362.165 USD
--           Olay sayısı ile sipariş sayısı arasında 1.240 fark -> Kontrol 5
SELECT
  COUNT(*)                            AS purchase_events,
  COUNT(DISTINCT user_pseudo_id)      AS purchasers,
  COUNT(DISTINCT transaction_id)      AS transactions,
  ROUND(SUM(purchase_revenue_usd), 2) AS total_revenue_usd
FROM `ga4-funnel-analytics-515610.ga4_funnel.stg_events`
WHERE event_name = 'purchase';


-- Kontrol 5: Olay ile sipariş arasındaki fark nereden geliyor?
-- Sonuç:
--   transaction_id_type | purchase_events | distinct_ids | revenue_usd
--   valid               | 4.786           | 4.451        | 330.348   <- 335 tekrar olay
--   (not set)           |   883           |     1        |  30.489   <- tek sipariş sayılmış
--   NULL                |    23           |     0        |   1.328
-- Sağlama: 335 + 882 + 23 = 1.240 (farkın tamamı) -> bkz. docs/data_quality.md not 8
SELECT
  CASE
    WHEN transaction_id IS NULL        THEN 'NULL'
    WHEN transaction_id = '(not set)' THEN '(not set)'
    ELSE 'valid'
  END                                 AS transaction_id_type,
  COUNT(*)                            AS purchase_events,
  COUNT(DISTINCT transaction_id)      AS distinct_ids,
  ROUND(SUM(purchase_revenue_usd), 2) AS revenue_usd
FROM `ga4-funnel-analytics-515610.ga4_funnel.stg_events`
WHERE event_name = 'purchase'
GROUP BY 1;


-- Kontrol 6: Tekrarlar temizlenince gerçek sipariş ve gelir rakamları
-- Kural  : Geçerli numara -> her numaradan ilk olay.
--          Numara yok -> aynı oturum + aynı tutar = aynı sipariş.
-- Teknik : ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...) + WHERE rn = 1
-- Sonuç  : 5.283 sipariş | 4.408 alıcı | 338.153 USD | ortalama sipariş 64,01 USD
--          Temizlenmemiş veriyle ortalama sipariş tutarı 81,35 USD görünüyordu (%27 şişkin).
SELECT
  COUNT(*)                            AS orders,
  COUNT(DISTINCT user_pseudo_id)      AS purchasers,
  ROUND(SUM(purchase_revenue_usd), 2) AS revenue_usd,
  ROUND(AVG(purchase_revenue_usd), 2) AS avg_order_value_usd
FROM (
  SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY order_key ORDER BY event_ts) AS rn
  FROM (
    SELECT
      user_pseudo_id,
      session_id,
      event_ts,
      purchase_revenue_usd,
      CASE
        WHEN transaction_id IS NULL OR transaction_id = '(not set)'
          THEN CONCAT('missing-', session_id, '-', IFNULL(CAST(purchase_revenue_usd AS STRING), 'na'))
        ELSE transaction_id
      END AS order_key
    FROM `ga4-funnel-analytics-515610.ga4_funnel.stg_events`
    WHERE event_name = 'purchase'
  )
)
WHERE rn = 1;
