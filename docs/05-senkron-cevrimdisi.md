# 05 — Senkron ve Çevrimdışı Davranış

## Karar
- Spark planında yönetilen yedek/Functions yok; yerel önbellek için **Firestore'un kendi kalıcı önbelleği** kullanılır.
  - Android: `persistenceEnabled: true` (varsayılan açık; açıkça ayarla).
  - Windows (Tauri/WebView2): `initializeFirestore(app, { localCache: persistentLocalCache({ tabManager: persistentSingleTabManager() }) })` (IndexedDB). **Ayrı SQLite önbelleği yok** (master prompt'taki SQLite isteği, bu yöntem aynı işi gördüğü için kapsam dışı bırakıldı; gerekirse Rust tarafına sonradan eklenir).
- **Kesinleştirme yalnız çevrimiçiyken**: `runTransaction` çevrimdışı çalışmaz; bu bilinçli kullanılır. Fatura kesme, ödeme, gider, iptal, transfer, stok işlemleri çevrimdışıyken **devre dışı** ("Çevrimdışısınız, taslak olarak kaydedebilirsiniz").
- Çevrimdışıyken yalnız **taslak fatura** (ve ana veri taslakları: cari/ürün) yazılabilir; Firestore bu yazmaları kuyruğa alır ve bağlantı gelince gönderir.

## Bağlantı durumu (UI'da her zaman görünür)
| Durum | Koşul | Metin (`connection.*`) | Renk |
|---|---|---|---|
| Çevrimiçi | ağ var, bekleyen yazma yok | Çevrimiçi | positive |
| Çevrimdışı | ağ yok | Çevrimdışı | warning |
| Senkronize ediliyor | bekleyen yazma var, ağ var | Senkronize ediliyor | info |
| Senkron hatası | kuyruktaki yazma reddedildi / tekrar denemeler başarısız | Senkron hatası | negative |

Kaynaklar: ağ → `connectivity_plus` (Android) / `navigator.onLine` + `online/offline` olayları (Windows); bekleyen yazma → `snapshot.metadata.hasPendingWrites` (liste/belge dinleyicileri `includeMetadataChanges: true` ile); beklemenin bitişi → `waitForPendingWrites()`.

## Senkron kuyruğu ekranı (Ayarlar → Senkronizasyon, Windows'ta üst çubuktan da açılır)
- Listelenenler: bekleyen taslaklar (`hasPendingWrites == true` olan faturalar/ana veri belgeleri) ve hata alanlar.
- Satır: belge türü + no/ad, kaydedilme zamanı, durum (Bekliyor / Hata + neden).
- Eylemler: **Yeniden dene**, **Taslağı yerel kopya olarak dışa aktar**, **Vazgeç** (onaylı). **Hiçbir bekleyen veri sessizce silinmez**; uygulama kapanırken bekleyen yazma varsa uyarı gösterilir.

## Taslak çakışması
- Taslak fatura alanları: `rev` (tamsayı, her kayıtta +1), `updatedAt`.
- Kesme işlemi (`issueInvoice`), okuduğu taslağın `rev`'ini kullanıcının ekrandaki `rev` ile karşılaştırır. Farklıysa işlem reddedilir ve "Bu fatura başka bir cihazda değiştirildi" iletişim kutusu: **Sunucudaki sürümü aç / Benimkini koru (üzerine yaz)**.
- Aynı taslağın iki cihazda çevrimdışı düzenlenmesi son yazanı kazanır (taslak olduğu için kabul); finansal etki kesme anında doğrulanır.

## Yeniden deneme
- SDK ağ hatalarını kendisi tekrar dener. Uygulama; `permission-denied`, `failed-precondition`, `aborted` hatalarını kuyrukta **Senkron hatası** olarak gösterir.
- `runTransaction` içinde `aborted` (yarış) → 3 kez üstel gecikmeyle (300/900/2700 ms) **aynı `txId` ile** yeniden dene; sonra kullanıcıya hata göster. Aynı `txId` olduğu için çift kayıt oluşmaz.

## Spark kotası notu
- Dinleyicileri sayfa/ekran bazında aç-kapat; büyük koleksiyonlarda `limit` + sayfalama. Başlangıçta tüm fatura/hareket koleksiyonunu dinleme.
- Dashboard `stats/summary` tek belgeden okunur (ucuz).
