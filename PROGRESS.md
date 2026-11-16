# PROGRESS — Görev Tahtası

Son güncelleme: 2026-11-16 · Sözleşme: v1.0.0 · Branch'ler: `hesap1-cekirdek`, `hesap2-android`, `hesap3-windows`

## Çalışma kuralları (3 ajan için)
1. Sohbet başında: `PROGRESS.md`, `CONTRACTS.md`, `docs/02`, `docs/04` oku. Kullanıcıya soru sorma, onay isteme; makul varsayımla ilerle, varsayımı bu dosyaya yaz.
2. Yalnız kendi klasörüne yaz: Ajan 1 → `firebase/ shared/ docs/ scripts/ .github/`; Ajan 2 → `apps/android/`; Ajan 3 → `apps/windows/`.
3. `shared/` veya sözleşme değişikliği gerekirse **Talepler** tablosuna yaz; Ajan 1 işler.
4. **İşi biten ajan boşta kalmaz**: tabloda sahibi olmayan (`—`) bir sonraki görevi kendi adına yazıp alır. Başka ajanın klasöründeki görev alınırsa o ajanın `Not` sütununda "yardım: Ajan N" yazılır ve yalnız o görevin dosyalarına dokunulur.
5. Testler en sonda (F7). Önce özellikler.
6. Her oturum sonu: bu tabloyu güncelle, commit at (kendi branch'inde).
7. Push reddedilirse: dosyalar yerelde kalır, kullanıcıya GitHub Claude App kurulumu gerektiği söylenir.

## Faz durumu
| Faz | Durum |
|---|---|
| F0 Sözleşme (Ajan 1) | **bitti** (model, kurallar, akışlar, token'lar, scriptler) |
| F1 Giriş, ayarlar, cari, ürün, depo | başlamadı |
| F2 Alış/Satış faturası + stok hareketi + depo | başlamadı |
| F3 Tahsilat/ödeme, kasa/banka, ekstre | başlamadı |
| F4 Gider, proje, şantiye maliyeti | başlamadı |
| F5 Genel Bakış, raporlar, PDF/Excel, yeniden hesapla | başlamadı |
| F6 Çevrimdışı, senkron kuyruğu | başlamadı |
| F7 Testler, rules testleri, paketleme | başlamadı |

## Görevler
| # | Görev | Sahip | Durum | Not |
|---|---|---|---|---|
| A1 | Android iskelet: Flutter proje, tema (tokens), router, Firebase init, giriş ekranı, alt menü | Ajan 2 | kod yazıldı, **derlenmedi** | Flutter SDK ortamda yok; `apps/android/README.md` "İlk kurulum" adımı (`flutter create`) gerekli |
| A2 | Android: para/tarih yardımcıları + `invoice_calculator` (04 §2) | Ajan 2 | kod yazıldı, **derlenmedi** | Algoritma Node'da BigInt aynasıyla `docs/04` örneğine karşı doğrulandı (405000). Dart testleri F7'de |
| A3 | Android: cari, ürün, depo ekranları + repository | Ajan 2 | — | |
| A4 | Android: fatura listesi, yeni fatura formu, `issueInvoice/cancelInvoice` servisleri | Ajan 2 | — | |
| A5 | Android: stok giriş/çıkış/sayım/transfer, stok listesi | Ajan 2 | — | |
| W1 | Windows iskelet: Vite+React+TS, Tauri 2, tema (tokens), router, sidebar+topbar, giriş | Ajan 3 | — | |
| W2 | Windows: para/tarih yardımcıları + `invoiceCalculator` (04 §2) | Ajan 3 | — | |
| W3 | Windows: cari, ürün, depo ekranları + repository | Ajan 3 | — | |
| W4 | Windows: fatura listesi/formu, `issueInvoice/cancelInvoice` servisleri | Ajan 3 | — | |
| W5 | Windows: stok ekranları ve işlemleri | Ajan 3 | — | |
| C1 | Ajan 1: Firestore emülatör seed verisi (örnek şirket, kullanıcı, depo, ürün) | Ajan 1 | — | |
| C2 | Ajan 1: `docs/05-senkron-cevrimdisi.md`, `07-ui-ekran-plani.md` | Ajan 1 | — | |
| C3 | Ajan 1: Logo/ikon varlıkları (`shared/assets`) | Ajan 1 | — | |

## Talepler (Ajan 2/3 → Ajan 1)
| Tarih | Kimden | Talep | Durum |
|---|---|---|---|
| 2026-11-16 | Ajan 2 | `shared/l10n/tr.json`'a ekle: `auth.{title,subtitle,email,password,signIn,signOut,required}`, `auth.errors.{invalidCredential,network,tooManyRequests,generic,noProfile,inactive}`, `common.comingSoon`, `profile.role.{admin,employee}`. Android şimdilik `lib/core/l10n/strings.dart` içindeki `pendingKeys` ile karşılıyor; tr.json'a eklenince onun değeri öncelikli olur. | açık |

## Varsayımlar ve kararlar
- Spark planı; Functions/Storage yok. Belge arşivi ertelendi.
- Tek `parties`, tek `accounts`, tek `payments`; fatura satırları belge içinde (02'ye bak).
- KDV oranları: 0, 1, 10, 20 (`constants.json`). Varsayılan %20.
- Para birimi yalnız TRY (döviz alanı ayrılmış, kullanılmıyor).
- Android (Ajan 2): `shared/*.json` Flutter asset olarak paket dışından okunamadığı için `apps/android/assets/shared/` altında kopyalanır (`tool/sync_shared.bat`). Giriş yöntemi e-posta/şifre. Firebase seçenekleri emülatör (`demo-sonar-finance`) için elle yazıldı; üretimde `flutterfire configure` ile değişecek. Emülatör: `--dart-define=USE_EMULATOR=true` (Android emülatör ana makine `10.0.2.2`).
- Ortalama maliyet (04 §3) — **Ajan 3 de aynısını uygulamalı**: `oldQty < 0` ise ağırlıkta 0 sayılır; `oldQty+inQty <= 0` ise yeni maliyet = giriş birim maliyeti. Birim maliyet = `roundHalfUp(taxable*1000 / qtyMilli)`. Dart: `apps/android/lib/data/invoice_calculator.dart` (`weightedAverageCost`, `unitCostMinorFromTaxable`).
- Para girdisi Türkçe biçimde ayrıştırılır: nokta binlik, virgül ondalık (`parseMinor`, en çok 2 ondalık; `parseMilli`, en çok 3).
- Ertelenenler: çek-senet, e-fatura/e-arşiv, e-defter, banka entegrasyonu, belge arşivi, teklif.
