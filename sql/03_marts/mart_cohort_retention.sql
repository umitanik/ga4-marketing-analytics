-- mart_cohort_retention.sql
-- Katman : 03_marts
-- Amaç   : Haftalık cohort retention: ilk ziyaret haftası × kanal × kaçıncı hafta, aktif kullanıcı sayısı.
-- İş sorusu: 3. İlk geldikleri haftaya ve kanala göre kullanıcılar ne oranda geri dönüyor?
--
-- Kurallar:
--   * Sadece YENİ kullanıcılar (dim_users.is_new_user): ilk ziyareti dönem içinde olanlar (docs/data_quality.md not 3).
--   * cohort_week: ilk ziyaretin haftası (pazartesi başlangıçlı, dim_users).
--   * week_number: kullanıcının KENDİ ilk ziyaret gününden itibaren geçen hafta = DIV(gün farkı, 7).
--     0 = ilk 7 gün, 1 = 8.-14. gün ... Takvim haftası kullanılmadı: pazar gelen biri ile pazartesi gelen biri
--     aynı "0. hafta" süresine sahip olsun diye.
--   * Aktif = o hafta içinde en az bir oturumu olan kullanıcı.
--   * Izgara (grid): Her cohort × kanal için bütün haftalar satır olarak üretilir; aktif kullanıcı yoksa 0 yazılır.
--     Eksik satır olsaydı, cohort'ları toplarken o cohort paydadan düşer ve retention olduğundan yüksek çıkardı.
--   * is_complete_week: cohort'taki EN GEÇ gelen kullanıcı için bile o hafta tamamen veri içinde mi?
--     (veri 2021-01-31'de bitiyor; son cohort'lar uzun süre izlenemez -> right censoring)
--   * is_partial_cohort: ilk cohort haftası (2020-10-26) sadece 1 Kasım'ı içeriyor.
--   * DİKKAT: cohort_size her week_number satırında tekrar eder. Toplarken tek bir week_number için toplanmalı.

CREATE OR REPLACE TABLE `ga4-funnel-analytics-515610.ga4_funnel.mart_cohort_retention`
AS

WITH new_users AS (
  SELECT
    user_pseudo_id,
    channel_group,
    first_visit_date,
    cohort_week
  FROM `ga4-funnel-analytics-515610.ga4_funnel.dim_users`
  WHERE is_new_user
),

user_activity AS (
  -- Kullanıcı × aktif olduğu hafta (tekil)
  SELECT DISTINCT
    s.user_pseudo_id,
    DIV(DATE_DIFF(s.session_date, u.first_visit_date, DAY), 7) AS week_number
  FROM `ga4-funnel-analytics-515610.ga4_funnel.fct_sessions` AS s
  JOIN new_users AS u
    ON s.user_pseudo_id = u.user_pseudo_id
  WHERE s.session_date >= u.first_visit_date
),

cohort_sizes AS (
  SELECT
    cohort_week,
    channel_group,
    COUNT(*) AS cohort_size
  FROM new_users
  GROUP BY cohort_week, channel_group
),

cohort_activity AS (
  SELECT
    u.cohort_week,
    u.channel_group,
    a.week_number,
    COUNT(*) AS active_users
  FROM user_activity AS a
  JOIN new_users AS u
    ON a.user_pseudo_id = u.user_pseudo_id
  GROUP BY u.cohort_week, u.channel_group, a.week_number
),

weeks AS (
  SELECT week_number
  FROM UNNEST(GENERATE_ARRAY(0, 13)) AS week_number
),

grid AS (
  -- Her cohort × kanal × hafta; cohort'un en erken kullanıcısı için bile veri dışında kalan haftalar hariç
  SELECT
    c.cohort_week,
    c.channel_group,
    c.cohort_size,
    w.week_number
  FROM cohort_sizes AS c
  CROSS JOIN weeks AS w
  WHERE DATE_ADD(c.cohort_week, INTERVAL 7 * w.week_number DAY) <= DATE '2021-01-31'
)

SELECT
  g.cohort_week,
  g.channel_group,
  g.week_number,
  g.cohort_size,
  IFNULL(a.active_users, 0)                                                         AS active_users,
  DATE_ADD(g.cohort_week, INTERVAL 7 * g.week_number + 12 DAY) <= DATE '2021-01-31' AS is_complete_week,
  g.cohort_week < DATE '2020-11-01'                                                 AS is_partial_cohort
FROM grid AS g
LEFT JOIN cohort_activity AS a
  ON  g.cohort_week   = a.cohort_week
  AND g.channel_group = a.channel_group
  AND g.week_number   = a.week_number;
