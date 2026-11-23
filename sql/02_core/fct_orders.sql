-- fct_orders.sql
-- Katman : 02_core (fact)
-- Amaç   : Sipariş başına TEK satır; tekrar eden satın alma olayları temizlenmiş.
-- Neden  : Ham veride 5.692 purchase olayı vardı ama tekrarlar ve eksik sipariş numaraları yüzünden
--          gelir %6,6, ortalama sipariş tutarı %27 şişkin görünüyordu (docs/data_quality.md not 8).
--          Bütün gelir metrikleri (kanal başına gelir, oturum geliri) bu tablodan hesaplanacak.
--          fct_sessions'tan ÖNCE kuruluyor, çünkü oturum geliri bu tabloya dayanıyor.
--
-- Kurallar:
--   * Geçerli transaction_id -> her numaradan ilk olay.
--   * transaction_id NULL ya da '(not set)' -> aynı oturum + aynı tutar = aynı sipariş.
--   * order_number: kullanıcının kaçıncı siparişi (1 = ilk sipariş, >1 = tekrar alım).

CREATE OR REPLACE TABLE `ga4-funnel-analytics-515610.ga4_funnel.fct_orders`
CLUSTER BY user_pseudo_id
AS

WITH purchases AS (
  SELECT
    user_pseudo_id,
    session_id,
    event_date AS order_date,
    event_ts   AS order_ts,
    transaction_id,
    purchase_revenue_usd,
    CASE
      WHEN transaction_id IS NULL OR transaction_id = '(not set)'
        THEN CONCAT('missing-', session_id, '-', IFNULL(CAST(purchase_revenue_usd AS STRING), 'na'))
      ELSE transaction_id
    END AS order_id
  FROM `ga4-funnel-analytics-515610.ga4_funnel.stg_events`
  WHERE event_name = 'purchase'
),

ranked AS (
  SELECT
    *,
    ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY order_ts) AS rn
  FROM purchases
)

SELECT
  order_id,
  user_pseudo_id,
  session_id,
  order_date,
  order_ts,
  transaction_id IS NOT NULL AND transaction_id != '(not set)'        AS has_transaction_id,
  purchase_revenue_usd                                                AS revenue_usd,
  ROW_NUMBER() OVER (PARTITION BY user_pseudo_id ORDER BY order_ts)   AS order_number
FROM ranked
WHERE rn = 1;
