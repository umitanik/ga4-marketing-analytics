# Veri Kalitesi Notları

Veri: `bigquery-public-data.ga4_obfuscated_sample_ecommerce` (2020-11-01 – 2021-01-31).
Veri seti Google tarafından anonimleştirildiği için bazı alanlar gizlenmiş ya da tutarsız. Aşağıda bulunan her sorun ve analizde nasıl ele alındığı yer alıyor.

İlgili keşif sorguları: [`sql/00_exploration/`](../sql/00_exploration/)

---

## 1. `add_shipping_info`
`begin_checkout` yapan kullanıcıların %99,99'unda var. Gerçek kullanıcı davranışından çok otomatik tetiklenen bir olay gibi görünüyor.

**Karar:** Funnel'dan çıkarıldı, `begin_checkout`'tan doğrudan `add_payment_info`'ya geçildi.

## 2. `view_item_list`
Üç ayda sadece 71 olay. Takip eksik.

**Karar:** Analizde kullanılmadı.

## 3. `first_visit`
~12.800 kullanıcının dönem içinde `first_visit` olayı yok. Muhtemelen 1 Kasım 2020'den önce gelmiş, geri dönen kullanıcılar.

**Karar:** Cohort analizi sadece ilk ziyareti dönem içinde olan kullanıcılarla yapılacak.

## 4. Sırasız funnel
Funnel oranları ilk aşamada kullanıcı sayılarının oranıyla hesaplandı (sırasız).

**Karar:** Final funnel, adımların sırayla yapılıp yapılmadığı kontrol edilerek kurulacak.

## 5. `traffic_source`: kullanıcı başına birden fazla kanal
Kullanıcıların %15,64'ünde (42.260 kişi) olaydan olaya farklı kanal bilgisi var. Bu yüzden kanal bazlı kullanıcı sayılarının toplamı (333.388) gerçek kullanıcı sayısını (270.154) aşıyor.

| Kanal sayısı | Kullanıcı | Oran |
|---|---|---|
| 1 | 227.894 | %84,36 |
| 2 | 29.029 | %10,75 |
| 3 | 7.940 | %2,94 |
| 4 | 3.384 | %1,25 |
| 5 | 1.430 | %0,53 |
| 6 | 412 | %0,15 |
| 7 | 62 | %0,02 |
| 8 | 3 | ~%0 |

**Sağlama:** Σ(kanal sayısı × kullanıcı) = 333.388. Yani aradaki farkın tamamı bu durumdan kaynaklanıyor.

GA4'te bu alanın kullanıcı başına sabit olması beklenir. Büyük ihtimalle anonimleştirmenin bir yan etkisi.

**Karar:** Her kullanıcıya tek kanal atandı. Öncelik `first_visit` olayındaki bilgi, `first_visit` yoksa kullanıcının ilk olayındaki bilgi (first-touch attribution). Uygulama: `sql/02_core/dim_users.sql`. Sonuç: 257.314 kullanıcının kanalı `first_visit`'ten, 12.840 kullanıcınınki ilk olaydan alındı. Kanal toplamı artık kullanıcı sayısına (270.154) eşit.

## 6. Gizlenmiş kanal değerleri ve self-referral
- `<Other>` ve `(data deleted)` değerleri kanal bilgisinin kabaca dörtte birini oluşturuyor. Bunlar anonimleştirme ve gizlilik nedeniyle gizlenmiş.
- `referral / shop.googlemerchandisestore.com` (~26.000 kullanıcı) mağazanın kendi alan adından gelen bir yönlendirme (self-referral). Gerçek bir kanal değil, takip ayarı hatası. Kullanıcının asıl geldiği kanal bilgisi kaybolmuş.

**Karar:** Kanallar beş gruba ayrıldı:

| Kanal grubu | Kural |
|---|---|
| Organic Search | `medium = 'organic'` |
| Paid Search | `medium = 'cpc'` |
| Direct | `source = '(direct)'` ve `medium = '(none)'` |
| Referral | `medium = 'referral'`, mağazanın kendi alan adı hariç |
| Unknown | `<Other>`, `(data deleted)` ve self-referral |

**Uygulama ve sonuç** (`dim_users`, her kullanıcı tek kanal):

| Kanal grubu | Kullanıcı | Oran |
|---|---|---|
| Organic Search | 101.782 | %37,68 |
| Unknown | 64.719 | %23,96 |
| Direct | 64.112 | %23,73 |
| Referral | 25.250 | %9,35 |
| Paid Search | 14.291 | %5,29 |
| **Toplam** | **270.154** | |

Kullanıcıların **%24'ünün kanalı bilinmiyor**. Unknown grubu analizden atılmadı (atılsaydı funnel ve toplamlar eksik çıkardı), ayrı bir grup olarak tutuldu. Kanal karşılaştırmaları bilinen kanallardaki **%76'lık** kullanıcıyı kapsıyor.

## 7. `session_start` olmayan oturumlar
Benzersiz oturum sayısı (`session_id`) 360.129, `session_start` olayı ise 354.970. Aradaki fark 5.159 (~%1,4). Muhtemel nedenler: 1 Kasım'dan önce başlayıp döneme sarkan oturumlar ya da kayıp `session_start` olayları. Buna karşılık her olayda `ga_session_id` dolu (oturumsuz olay: 0).

**Karar:** Oturumlar `session_start` olayıyla değil, her olayda dolu olan `session_id` ile tanımlandı. Etkisi küçük olduğu için daha fazla araştırılmadı.

## 8. Satın alma olaylarında tekrar ve eksik sipariş numarası
5.692 `purchase` olayı var, ama yalnızca 4.451 geçerli benzersiz sipariş numarası.

| Grup | Olay | Benzersiz numara | Gelir (USD) |
|---|---|---|---|
| Geçerli numara | 4.786 | 4.451 | 330.348 |
| `(not set)` | 883 | 1 | 30.489 |
| NULL | 23 | 0 | 1.328 |

- Geçerli numaralı siparişlerde **335 tekrar olay** var (%7). Muhtemelen teşekkür sayfasının yenilenmesinden kaynaklanıyor.
- `(not set)` bir metin olduğu için `COUNT(DISTINCT)` 883 olayı **tek sipariş** sayıyor.
- Sağlama: 335 + 882 + 23 = 1.240, yani olay ile sipariş arasındaki farkın tamamı.

Bu sorun doğrudan gelir metriklerini etkilediği için (kanal başına gelir, ortalama sipariş tutarı) araştırıldı.

**Karar:**
- Geçerli numaralı siparişlerde her numaradan yalnızca **ilk olay** tutuldu.
- Numarası olmayanlarda **aynı oturum + aynı tutar = aynı sipariş** kuralı uygulandı.
- Bu mantık `fct_orders` tablosunda uygulanıyor.

| Metrik | Temizlemeden önce | Temizlendikten sonra |
|---|---|---|
| Sipariş | 4.452 | 5.283 |
| Gelir (USD) | 362.165 | 338.153 (−%6,6) |
| Ortalama sipariş tutarı (USD) | 81,35 | 64,01 |
| Alıcı | 4.419 | 4.408 |

Temizlenmemiş veriyle hesaplanan ortalama sipariş tutarı **%27 şişkin** çıkıyordu.

Alıcı sayısındaki 11 kişilik düşüş: Bu kullanıcıların satın alma olayları, başka bir kullanıcıda daha önce kaydedilmiş sipariş numaralarını taşıyor. Muhtemelen anonimleştirmenin bir yan etkisi. Etkisi %0,25 olduğu için kabul edildi.

## 9. `add_to_cart` funnel'ın zorunlu adımı değil
Sıralı funnel ilk kurulduğunda (sepete ekleme zorunlu adım) ödemeye geçen kullanıcıların yarısı elendi. Ödemeye geçen 9.715 kullanıcı:

| Grup | Kullanıcı | Pay |
|---|---|---|
| Hiç sepete eklemeden ödemeye geçmiş | 4.058 | %41,8 |
| Önce ödemeye geçmiş, sepete sonra eklemiş | 927 | %9,5 |
| Sırayla yapmış (önce sepet, sonra ödeme) | 4.730 | %48,7 |

**Olası açıklamalar ve test:**
1. *Sepet 1 Kasım'dan önce doldurulmuş.* Test: sepetsiz ödemeye geçen 4.058 kişinin **3.348'i (%82,5) yeni kullanıcı**, yani dönem öncesinde siteye hiç gelmemişler. Bu açıklama çoğunluk için **elendi**.
2. *"Hemen al" akışı:* Sepeti atlayan bir satın alma yolu.
3. *`add_to_cart` takibinin eksik olması.*

2 ve 3 bu veriyle ayırt edilemiyor. Gerçek bir şirkette ürün / mühendislik ekibine "hemen al akışı var mı, hangi olayları tetikliyor?" diye sorulur.

**Karar:** Üç açıklama da aynı karara çıkıyor: sepete ekleme funnel'da **zorunlu kapı yapılmadı**. Ana funnel: `view_item` → `begin_checkout` → `add_payment_info` → `purchase` (sıralı). Sepete ekleme bilgi amaçlı ayrı bir metrik olarak raporlanıyor.

Sepete ekleme zorunlu tutulsaydı sepet → ödeme geçişi %40,1, genel dönüşüm %1,05 görünürdü. Yani funnel'ın en büyük sızıntısı yanlış yerde gösterilmiş olurdu.

## 10. 26 Ocak 2021'den itibaren gelir takibi bozuk
Haftalık trendde son haftanın ortalama sipariş tutarı 17,28 USD çıktı (diğer haftalar 52 – 79 USD). Günlük kırılıma inildi:

| Tarih | Sipariş | Sıfır gelirli | Pay |
|---|---|---|---|
| 18-25 Ocak | 449 | 36 | ~%8 |
| 26 Ocak | 53 | 31 | %58 |
| 27 Ocak | 53 | 41 | %77 |
| 28 Ocak | 56 | 51 | %91 |
| 29 Ocak | 51 | 45 | %88 |
| 30 Ocak | 29 | 24 | %83 |
| 31 Ocak | 18 | 18 | %100 |

Siparişler normal hızda gelmeye devam ediyor, ama 26 Ocak'tan itibaren çoğu **0 gelirle** kaydedilmiş. Gerçek bir davranış değil, takip arızası (muhtemelen sitede satın alma olayına gelir gönderilmesini bozan bir değişiklik).

**Taban seviye:** Kasım ortasından itibaren her hafta siparişlerin ~%2-8'i sıfır gelirli (26 Ocak öncesi toplam %4,0). Bunlar bedava ürün ya da %100 indirim gibi gerçek sıfırlar olabilir; bu veriyle ayırt edilemiyor.

**Etkisi:** Taban seviye düşüldüğünde ~200 siparişin geliri kayıp, yaklaşık 13.800 USD, toplam gelirin ~%4'ü.

**Neden önce yakalanmadı:** `fct_orders` kontrol 1 "gelirsiz sipariş = 0" bulmuştu, ama sadece `IS NULL` kontrol ediliyordu. Gelir NULL değil 0 olarak kaydedilmiş. Veri testleri NULL, 0 ve negatif değerleri birlikte kontrol etmeli. Sorun toplam rakamlarda görünmedi, zaman serisinde göründü.

**Karar:**
- `mart_daily_kpis`'e `is_revenue_tracked` bayrağı eklendi (tarih < 2021-01-26). Gelir trendlerinde 26-31 Ocak dışarıda bırakılır ya da işaretlenir. Sipariş sayıları ve dönüşüm oranları kullanılmaya devam eder.
- Ortalama sipariş tutarı gelir > 0 olan siparişler üzerinden raporlanır: **69,41 USD** (sıfırlar dahil 64,01).
- Kanal bazlı gelir metrikleri ~%4 düşük. Arızanın kanallara eşit dağıldığı varsayımıyla kanal karşılaştırmaları geçerliliğini koruyor.
- Gerçek bir şirkette: mühendislik ekibine 26 Ocak'taki değişiklik sorulur ve günlük ortalama sipariş tutarı için otomatik bir uyarı (alert) kurulur.

## 11. `first_visit` olayından önce görülen kullanıcılar
Lojistik regresyon verisinde 1 kullanıcı ilk oturumunda satın almış görünüyordu ama 7 günlük hedefi 0'dı. "Sonradan alan" sayısı çıkarmayla (2.733 − 1.642 = 1.091) ve doğrudan sayımla (1.092) farklı çıkınca yakalandı.

**Neden:** Kullanıcı 10 Kasım'da gelip alışveriş yapmış, `first_visit` olayı ise 4 gün sonra kaydedilmiş. Sipariş, ilk ziyaret tarihinden önce kaldığı için "ilk ziyaretten itibaren 7 gün içinde" koşulunu sağlamıyor. Bir takip kenar durumu: `first_visit` ilk gelişte tetiklenmemiş ya da geç kaydedilmiş.

**Kapsam:** 257.314 yeni kullanıcının **15'i (%0,006)** `first_visit` olayından önce görülmüş. En büyük fark 77 gün.

**Etkisi:**
- Model: Bu kullanıcıların "ilk oturum" özellikleri, ilk ziyaret tarihinden önceki bir oturumdan geliyor. 15 kişi, sonuçları değiştirmez.
- Retention: Etkilenmiyor. İlk ziyaretten 1-6 gün önceki oturumlar 0. haftaya düşüyor, daha öncekiler negatif hafta olup 0-13 ızgarasına girmiyor.

**Karar:** Dokunulmadı. Tanımı değiştirmek (ör. ilk görülme tarihini ilk ziyaret saymak) cohort haftalarını ve bütün mart tablolarını yeniden kurmayı gerektirirdi; 15 kullanıcı için değmez. Notebook'taki sayım, hedefle kesiştirilecek şekilde düzeltildi.

