-- stg_events.sql
-- Katman : 01_staging
-- Amaç   : Ham GA4 olaylarını analiz edilebilir, düz (flat) bir tabloya çevirmek.
--          - Tarih ve zaman kolonları doğru tiplere çevrilir.
--          - event_params içindeki gerekli anahtarlar ayrı kolonlara açılır.
--          - Her oturuma benzersiz bir session_id verilir.
-- İlke   : Staging temizler ve düzenler ama FİLTRELEMEZ. Hangi olayın analize gireceği
--          kararı (bkz. docs/data_quality.md) core ve mart katmanlarında uygulanır.
--
-- Not    : Tablo bölümlenmedi (PARTITION BY kullanılmadı). BigQuery Sandbox'ta bölümler
--          60 günde siliniyor; veri 2020-2021 tarihli olduğu için tarih bazlı bölümler
--          oluşturulur oluşturulmaz silinirdi. Bunun yerine CLUSTER BY kullanıldı.

CREATE OR REPLACE TABLE `ga4-funnel-analytics-515610.ga4_funnel.stg_events`
CLUSTER BY user_pseudo_id, event_name
AS

WITH base AS (
  SELECT
    -- Zaman
    PARSE_DATE('%Y%m%d', event_date)   AS event_date,
    TIMESTAMP_MICROS(event_timestamp)  AS event_ts,

    -- Olay ve kullanıcı
    event_name,
    user_pseudo_id,

    -- Oturum bilgisi (event_params içinden)
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id')        AS ga_session_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number')    AS session_number,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'engagement_time_msec') AS engagement_time_msec,

    -- Sayfa bilgisi
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location') AS page_location,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_title')    AS page_title,

    -- Olay anındaki (oturum seviyesi) kanal bilgisi
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'source')   AS event_source,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'medium')   AS event_medium,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'campaign') AS event_campaign,

    -- Kullanıcının ilk geldiği kanal (kullanıcı seviyesi)
    traffic_source.source AS user_source,
    traffic_source.medium AS user_medium,
    traffic_source.name   AS user_campaign,

    -- Cihaz ve konum
    device.category         AS device_category,
    device.operating_system AS device_os,
    geo.country             AS country,

    -- E-ticaret (sadece purchase olaylarında dolu)
    ecommerce.transaction_id,
    ecommerce.purchase_revenue_in_usd AS purchase_revenue_usd

  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
)

SELECT
  *,
  -- ga_session_id tek başına benzersiz değil (farklı kullanıcılarda aynı olabilir),
  -- bu yüzden kullanıcı kimliğiyle birleştirilerek benzersiz oturum kimliği üretilir.
  CONCAT(user_pseudo_id, '-', CAST(ga_session_id AS STRING)) AS session_id
FROM base;
