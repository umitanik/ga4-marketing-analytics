-- dim_users.sql
-- Katman : 02_core (dimension)
-- Amaç   : Her kullanıcı için TEK satır: edinim kanalı, ilk görülme tarihi, yeni kullanıcı mı,
--          cohort haftası, cihaz, ülke.
-- Neden  : Kanal analizi ve cohort'lar bu tabloya bağlanacak. Ham veride kullanıcıların %15,6'sında
--          birden fazla kanal bilgisi vardı (docs/data_quality.md not 5); burada her kullanıcıya
--          tek kanal atanıyor.
--
-- Kurallar:
--   * Edinim kanalı önceliği: first_visit olayındaki bilgi; first_visit yoksa kullanıcının ilk olayı.
--   * Kanal grupları (docs/data_quality.md not 6):
--       Organic Search : medium = 'organic'
--       Paid Search    : medium = 'cpc'
--       Direct         : source = '(direct)' ve medium = '(none)'
--       Referral       : medium = 'referral', mağazanın kendi alan adı (self-referral) hariç
--       Unknown        : <Other>, (data deleted), self-referral ve diğerleri
--   * is_new_user: dönem içinde first_visit olayı var mı (not 3). Cohort'lar sadece yeni kullanıcılarla kurulur.
--   * cohort_week: first_visit tarihinin haftası (pazartesi başlangıçlı). Yeni olmayanlar için NULL.

CREATE OR REPLACE TABLE `ga4-funnel-analytics-515610.ga4_funnel.dim_users`
CLUSTER BY channel_group
AS

WITH first_events AS (
  -- Kullanıcının dönem içindeki ilk olayı
  SELECT *
  FROM (
    SELECT
      user_pseudo_id,
      event_date,
      user_source,
      user_medium,
      device_category,
      country,
      ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY event_ts) AS rn
    FROM `ga4-funnel-analytics-515610.ga4_funnel.stg_events`
  )
  WHERE rn = 1
),

first_visits AS (
  -- Kullanıcının first_visit olayı (varsa; birden fazlaysa ilki)
  SELECT *
  FROM (
    SELECT
      user_pseudo_id,
      event_date AS first_visit_date,
      user_source,
      user_medium,
      ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY event_ts) AS rn
    FROM `ga4-funnel-analytics-515610.ga4_funnel.stg_events`
    WHERE event_name = 'first_visit'
  )
  WHERE rn = 1
),

users AS (
  SELECT
    e.user_pseudo_id,
    e.event_date                                                    AS first_seen_date,
    v.first_visit_date,
    v.first_visit_date IS NOT NULL                                  AS is_new_user,
    COALESCE(v.user_source, e.user_source)                          AS acquisition_source,
    COALESCE(v.user_medium, e.user_medium)                          AS acquisition_medium,
    IF(v.user_pseudo_id IS NOT NULL, 'first_visit', 'first_event')  AS acquisition_basis,
    e.device_category,
    e.country
  FROM first_events AS e
  LEFT JOIN first_visits AS v
    ON e.user_pseudo_id = v.user_pseudo_id
)

SELECT
  *,
  CASE
    WHEN acquisition_medium = 'organic' THEN 'Organic Search'
    WHEN acquisition_medium = 'cpc'     THEN 'Paid Search'
    WHEN acquisition_source = '(direct)' AND acquisition_medium = '(none)' THEN 'Direct'
    WHEN acquisition_medium = 'referral'
         AND acquisition_source != 'shop.googlemerchandisestore.com' THEN 'Referral'
    ELSE 'Unknown'
  END                                         AS channel_group,
  DATE_TRUNC(first_visit_date, WEEK(MONDAY))  AS cohort_week
FROM users;
