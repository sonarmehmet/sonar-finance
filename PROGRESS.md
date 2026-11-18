# PROGRESS — Görev Tahtası

Son güncelleme: 2026-11-16 · Sözleşme: v1.0.4 · Branch'ler: `hesap1-cekirdek`, `hesap2-android`, `hesap3-windows`

## Çalışma kuralları (3 ajan için)
1. Sohbet başında: `PROGRESS.md`, `CONTRACTS.md`, `docs/02`, `docs/04` oku. Kullanıcıya soru sorma, onay isteme; makul varsayımla ilerle, varsayımı bu dosyaya yaz.
2. Yalnız kendi klasörüne yaz: Ajan 1 → `firebase/ shared/ docs/ scripts/ .github/`; Ajan 2 → `apps/android/`; Ajan 3 → `apps/windows/`.
3. `shared/` veya sözleşme değişikliği gerekirse **Talepler** tablosuna yaz; Ajan 1 işler.
4. **İşi biten ajan boşta kalmaz**: tabloda sahibi olmayan (`—`) bir sonraki görevi kendi adına yazıp alır. Başka ajanın klasöründeki görev alınırsa o ajanın `Not` sütununda "yardım: Ajan N" yazılır ve yalnız o görevin dosyalarına dokunulur.
5. Testler en sonda (F7). Önce özellikler.
6. Her oturum sonu: bu tabloyu güncelle, commit at (kendi branch'inde).
7. Push reddedilirse: dosyalar yerelde kalır, kullanıcıya GitHub Claude App kurulumu gerektiği söylenir.

## DUYURULAR (Ajan 1 → Ajan 2/3) — önce bunları oku
**v1.0.3 (main).** Branch'inizi hemen güncelleyin: `git fetch origin && git merge origin/main` (çakışırsa `shared/`, `docs/`, `firebase/`, `CONTRACTS.md` için **main'in** sürümünü alın).
1. **Hesap düzeltmesi (v1.0.2) — Ajan 2 acil, Ajan 3 baştan doğru yazsın.** KDV **dahil** fiyatlı satırda `net` ve `discount` değişti (04 §2):
   `net = roundHalfUp(grossBeforeDisc * 10000 / (10000 + vatBp))`, `discount = net - taxable` (yani KDV hariç iskonto). `total`, `taxable`, `vat` aynı kalır; KDV **hariç** mod değişmedi. Android `invoice_calculator.dart` içinde `netMinor: taxable + discount` ve `discountMinor: discount` satırları buna göre düzelecek (`discountMinor: net - taxable`, `netMinor: roundHalfUp(grossBeforeDisc*10000, 10000+vatBp)`).
   Doğrulama vektörleri hazır: `shared/test-vectors/invoice-calc.json` (51 fatura, yuvarlama, ortalama maliyet, birim maliyet, özet delta). Testler F7'de (T2); şimdilik yalnız kodu düzeltin.
2. **Durumlar:** `paymentStatus` artık `none` (taslak) | `unpaid` | `partial` | `paid` | `void` (iptal). Taslak yazarken `none`, iptalde `void`.
3. **`stats/summary.months[ay]`:** `{incomeMinor, expenseMinor, inMinor, outMinor}`; `ledger_entries` ve `account_movements` belgelerine `createdAt` yazılır (04 §11).
4. **Taslak faturada `rev`** (her kayıtta +1); kesmede ekrandaki `rev` ≠ sunucudaki ise reddet (05).
5. **Yeni spesifikasyon:** `docs/08-rapor-panel-spesifikasyonu.md` (Genel Bakış formülleri, proje kârlılık, cari ekstre sütunları, 12 rapor). F3-F5 görevleri buna uyar.
6. **Ajan 2'nin l10n talebi (2026-11-16) uygulandı:** 72 anahtar `shared/l10n/tr.json`'a eklendi. `apps/android/tool/sync_shared` çalıştırın, `pending_strings.dart` içindeki satırları silebilirsiniz.
7. **Görev sırası:** A6..A9 ve W6..W9 görev tablosunda; sahibi boş olanı alın. F7 testleri (T1-T4) en sonda.
8. **Ajan 3:** henüz branch yok. `hesap3-windows` oluşturup W1'den başlayın; boşta kalan Android görevlerini (A6+) Ajan 2 ile çakışmadan almadan önce tabloda sahibini yazın.
9. **v1.0.4 (2026-11-17):** Ajan 2'nin `stock_movements.note?` talebi işlendi (docs/02). Android'in `pending_strings.dart` dosyasındaki 67 yeni metin `shared/l10n/tr.json`'a taşındı (`errors.*`, `invoice.*`, `stock.*`); Ajan 3 aynı anahtarları kullanır.
10. **Çapraz denetim (Ajan 1 → Ajan 2):** `invoice_service.dart` (kes/iptal) docs/04 ve `firestore.rules` ile satır satır karşılaştırıldı: belge ID'leri, okuma-sonra-yazma sırası, `rev` kontrolü, sayaç, hareket belgeleri, iptal kuralları uyumlu; sözleşme ihlali bulunmadı. Windows `issueInvoice`/`cancelInvoice` aynı davranışla yazılıyor.
11. **Windows durumu:** W1-W3 (iskelet, hesap katmanı, cari/ürün/depo) `hesap3-windows` branch'inde (Ajan 1 yardım). Ajan 3 başlarsa W4'ten devam eder; W4'ü ben alıyorum, tabloda sahip yazılı.

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
| A1 | Android iskelet: Flutter proje, tema (tokens), router, Firebase init, giriş ekranı, alt menü | Ajan 2 | — | |
| A2 | Android: para/tarih yardımcıları + `invoice_calculator` (04 §2) | Ajan 2 | — | |
| A3 | Android: cari, ürün, depo ekranları + repository | Ajan 2 | — | |
| A4 | Android: fatura listesi, yeni fatura formu, `issueInvoice/cancelInvoice` servisleri | Ajan 2 | — | |
| A5 | Android: stok giriş/çıkış/sayım/transfer, stok listesi | Ajan 2 | — | |
| W1 | Windows iskelet: Vite+React+TS, Tauri 2, tema (tokens), router, sidebar+topbar, giriş | Ajan 1 (yardım) | bitti (derlenmedi) | `hesap3-windows` branch. Vite+React+TS+Tauri 2 iskeleti, tema (tokens→CSS değişkenleri), HashRouter, sidebar+topbar, giriş, bağlantı rozeti. Ağ yok: `npm install`/`tauri build` bu ortamda çalıştırılamadı, ilk derleme Windows makinede denenmeli. |
| W2 | Windows: para/tarih yardımcıları + `invoiceCalculator` (04 §2) | Ajan 1 (yardım) | bitti (doğrulandı) | `src/core/money.ts`, `src/core/calc/invoiceCalculator.ts`; `npm test` 51 vektörün hepsini geçiyor (v1.0.2 KDV dahil iskonto dahil). |
| W3 | Windows: cari, ürün, depo ekranları + repository | Ajan 1 (yardım) | bitti (derlenmedi) | Cari (liste+detay+ekstre, 08 §5), ürün, depo ekranları; `src/data/{models,repositories}.ts`, `core/hooks/useSnapshot.ts`, ortak bileşenler (`components/`). Tip kontrolü yalnız stub ile yapıldı; gerçek `npm run typecheck` Windows makinede çalıştırılmalı. |
| W4 | Windows: fatura listesi/formu, `issueInvoice/cancelInvoice` servisleri | Ajan 1 (yardım) | bitti (derlenmedi) | Fatura listesi (sekmeler, arama, daha fazla), form (kalem editörü, toplam kutusu, taslak/kes, çakışma diyaloğu, sabit txId), detay (iptal), `invoiceService.ts`. Tip kontrolü yalnız stub ile; gerçek derleme Windows makinede. |
| W5 | Windows: stok ekranları ve işlemleri | Ajan 1 (yardım) | bitti (derlenmedi) | `stockService.ts` (giriş/çıkış/sayım/transfer, Android ile aynı), `StockActionDialog`, Hareketler sekmesi. |
| A6 | Android: tahsilat/ödeme, kasa/banka hesapları, transfer, cari ekstre (04 §5-§7, 08 §5) | — | — | |
| A7 | Android: gider, projeler, proje detay/disiplin bütçesi (08 §4) | — | — | |
| A8 | Android: Ana Sayfa paneli, raporlar (08 §1-§3,§6), PDF paylaş | — | — | |
| A9 | Android: çevrimdışı/senkron durumu, kuyruk ekranı (05) | — | — | |
| W6 | Windows: tahsilat/ödeme, kasa/banka, transfer, cari ekstre | Ajan 1 (yardım) | bitti (derlenmedi) | `paymentService.ts` (tahsilat/ödeme, iptal, hesap, transfer), Kasa-Banka sayfası, ödeme penceresi (FIFO dağıtım), cari detayında fatura/tahsilat/ödeme sekmeleri. l10n: `payment.*`, `cashBank.*`, `errors.*` eklendi. |
| W7 | Windows: gider/gelir, projeler, proje detay (08 §4) | — | — | |
| W8 | Windows: Genel Bakış, raporlar, PDF/Excel (08) | — | — | |
| W9 | Windows: çevrimdışı/senkron, kuyruk ekranı, kullanıcı yönetimi, ayarlar, yedekleme ekranı | — | — | |
| C5 | Ajan 1: `firebase/tools/recalc.js` tutarlılık/düzeltme aracı | Ajan 1 | bitti | |
| T1 | **F7** Firestore rules testleri (emülatör, `firebase/rules-tests`) | — | bekliyor (en sonda) | Ajan 1 |
| T2 | **F7** Hesap vektörleri testleri (Dart ve TS, `shared/test-vectors`) | — | bekliyor (en sonda) | Ajan 2 / 3 |
| T3 | **F7** Yedek/geri yükleme provası (06) | — | bekliyor (en sonda) | Ajan 1 |
| T4 | **F7** APK/EXE paketleme ve kurulum denemesi | — | bekliyor (en sonda) | Ajan 2 / 3 |
| C1 | Ajan 1: Firestore emülatör seed verisi (örnek şirket, kullanıcı, depo, ürün) | Ajan 1 | bitti | `scripts/seed_emulator.bat`; giriş admin@sonar.local / Test1234! |
| C2 | Ajan 1: `docs/05`, `06`, `07` + `firebase/tools` export/restore | Ajan 1 | bitti | |
| C4 | Ajan 1: referans hesaplayıcı + test vektörleri (`shared/reference`, `shared/test-vectors/invoice-calc.json`); A2/W2 çıktıları bunlarla eşleşmeli (testler F7'de çalıştırılır) | Ajan 1 | bitti | |
| C3 | Ajan 1: Logo/ikon varlıkları (`shared/assets`) | Ajan 1 | bitti | svg + png + .ico |

## Talepler (Ajan 2/3 → Ajan 1)
| Tarih | Kimden | Talep | Durum |
|---|---|---|---|

## Varsayımlar ve kararlar
- Spark planı; Functions/Storage yok. Belge arşivi ertelendi.
- Tek `parties`, tek `accounts`, tek `payments`; fatura satırları belge içinde (02'ye bak).
- KDV oranları: 0, 1, 10, 20 (`constants.json`). Varsayılan %20.
- Para birimi yalnız TRY (döviz alanı ayrılmış, kullanılmıyor).
- Ertelenenler: çek-senet, e-fatura/e-arşiv, e-defter, banka entegrasyonu, belge arşivi, teklif.
