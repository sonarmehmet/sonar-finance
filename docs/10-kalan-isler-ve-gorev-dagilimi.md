# 10 — Kalan İşler ve Ajan Görev Dağılımı

Durum tarihi: 2026-11-19. Kaynak: `PROGRESS.md` (güncel durum her zaman orada).

## 1) Şu an ne var, ne yok?
| Alan | Durum |
|---|---|
| Sözleşme (model, kurallar, akışlar, token'lar, test vektörleri, yedek/yeniden hesapla araçları) | **Bitti** (Ajan 1, C1–C5) |
| Android A1–A9 (cari, ürün, depo, fatura, stok, tahsilat/ödeme, kasa/banka, gider, proje, panel, rapor, senkron durumu) | **Kod yazıldı, derlenmedi** |
| Windows W1–W9 (aynı kapsam + kullanıcı yönetimi, ayarlar, yedek ekranı, Excel/PDF) | **Kod yazıldı, derlenmedi** |
| Birim testleri | Android: yazıldı, çalıştırılmadı. Windows: hesaplayıcı vektör testi var (`npm test`) |
| Gerçek Firebase / emülatörde uçtan uca deneme | **Yapılmadı** |
| Rules testleri, paketleme doğrulaması (F7) | **Başlamadı** |

"Derlenmedi" = yazıldığı ortamda Flutter/Rust/Node derleyicisi çalıştırılamadı; ilk derlemede hata çıkması beklenir.

## 2) Kalan işler (öncelik sırasıyla)
### P0 — Çalıştığını kanıtla (önce bunlar)
1. **Android derleme turu:** `tool\setup_android.bat` → `flutter analyze` → `flutter test` → hataları düzelt.
2. **Windows derleme turu:** `npm install` → `npm run typecheck` → `npm test` → `npm run build` → `scripts\run_windows.bat` (Tauri).
3. **Emülatör uçtan uca deneme** (aşağıdaki "Kabul senaryoları").
4. **20 çağrı sınırı riski:** `firestore.rules` bir işlemde en fazla 20 `get/exists` çağrısına izin verir; çok kalemli fatura bunu aşabilir. Test et; aşıyorsa kural/akış optimize edilir veya "faturada en fazla N kalem" kuralı sözleşmeye yazılır.
5. **Dizin (index) doğrulaması:** iki uygulamanın kullandığı tüm sorgular `firebase/firestore.indexes.json` ile karşılaştırılır; eksik dizin = canlıda boş liste/hata.

### P1 — Üretime hazırlık
6. Rules birim testleri (`@firebase/rules-unit-testing`, emülatör): yetki, `newTx`, `backedUpdate`, sayaç, değişmez alanlar.
7. Yedek → sıfırla → geri yükle turu (docs/06: fark = 0).
8. İlk yönetici için `firebase/tools/bootstrap_admin.js` (konsolda elle yapmak yerine tek komut).
9. Android: PDF/Excel dışa aktarma (pub.dev erişimi olan ortamda `pdf`, `printing`, `share_plus`); rapor filtreleri (proje/cari/tür); kasa/cari raporlarında 50 hareket sınırı yerine sayfalama.
10. Çevrimdışı doğrulama: uçak modunda fatura taslağı, geri gelince eşitleme; çakışma (`rev`) senaryosu.

### P2 — Cila
11. Android release imzası (kendi keystore) — Play Store istenirse.
12. Windows otomatik güncelleme (isteğe bağlı), fatura yazdırma şablonu.
13. Android widget/servis testleri (`fake_cloud_firestore`), Windows servis testleri (emülatör).
14. Erişilebilirlik ve büyük yazı denemesi (docs/07).

## 3) Kim ne yapacak?
> Ajan = ayrı Claude hesabı/oturumu. Herkes kendi klasörüne yazar, `PROGRESS.md`'yi günceller, küçük commit atar. Soru sormaz; varsayımı `PROGRESS.md`'ye yazar.

### Ajan 1 — Çekirdek / Sözleşme / Altyapı (`firebase/`, `shared/`, `docs/`, `scripts/`)
- R1: `firebase/tests/` altında rules birim testleri (madde 6) + 20 çağrı sınırı ölçümü (madde 4).
- R2: İndeks denetimi: iki uygulamadaki sorguları tara → `firestore.indexes.json` tamamla (madde 5).
- R3: `firebase/tools/bootstrap_admin.js` (madde 8) ve backup→reset→restore otomasyon testi (madde 7).
- R4: Emülatör uçtan uca senaryo betiği (`scripts/e2e_emulator.bat`): seed → örnek fatura/tahsilat/gider → `recalc.js` farkı 0.
- R5: Sözleşme değişirse sürümü artır, iki uygulamaya `PROGRESS.md > Talepler` ile bildir.

### Ajan 2 — Android (`apps/android/`)
- A10: Derleme turu (madde 1): kullanıcıdan gelen `flutter analyze/test` çıktısına göre hata düzeltme.
- A11: PDF/Excel dışa aktarma + paylaşım menüsü; rapor filtreleri ve sayfalama (madde 9).
- A12: Çevrimdışı senaryo düzeltmeleri; kapanışta bekleyen yazma uyarısı (madde 10).
- A13: Widget/servis testleri (madde 13), release imza rehberi (madde 11).

### Ajan 3 — Windows (`apps/windows/`)
- W10: Derleme turu (madde 2): `typecheck`, `test`, `build`, Tauri derlemesi; hata düzeltme.
- W11: Windows servis testleri (emülatör ile), yedek/geri yükleme ekranının doğrulanması.
- W12: Fatura yazdırma/PDF şablonu cilası; Tauri güncelleme (madde 12).
- W13: Kabul senaryolarının Windows tarafını uygulayıp sonuçları `PROGRESS.md`'ye yazmak.

### Kullanıcı (sen)
- Programları kur ([09 rehberi](09-kurulum-rehberi.md) Bölüm 2), emülatörle dene, **hata çıktısını ajana yapıştır**.
- Gerçek Firebase projesini kendi Google hesabınla oluştur (Bölüm 7–8) — bunu ajanlar senin yerine yapamaz.
- Her büyük işlemden önce yedek al.

## 4) Ajanlara yapıştırılacak hazır istemler
**Ajan 1:** `Sen SONAR FINANCE Ajan 1'sin. Repo: sonarmehmet/sonar-finance, branch hesap1-cekirdek. PROGRESS.md ve docs/10-kalan-isler-ve-gorev-dagilimi.md oku. R1–R5'i sırayla yap. Sadece firebase/, shared/, docs/, scripts/ içine yaz. Soru sorma; varsayımı PROGRESS.md'ye yaz; küçük commit at ve push et.`

**Ajan 2:** `Sen SONAR FINANCE Ajan 2'sin (Android/Flutter). Repo: sonarmehmet/sonar-finance, branch hesap2-android. PROGRESS.md ve docs/10 oku. A10–A13'ü sırayla yap. Sadece apps/android/ içine yaz. Soru sorma; PROGRESS.md'yi güncelle; küçük commit + push. Derleme hatası çıktısı sana yapıştırılırsa önce onları düzelt.`

**Ajan 3:** `Sen SONAR FINANCE Ajan 3'sün (Windows/React+Tauri). Repo: sonarmehmet/sonar-finance, branch hesap3-windows. PROGRESS.md ve docs/10 oku. W10–W13'ü sırayla yap. Sadece apps/windows/ içine yaz. Soru sorma; PROGRESS.md'yi güncelle; küçük commit + push. Derleme hatası çıktısı sana yapıştırılırsa önce onları düzelt.`

## 5) Kabul senaryoları (emülatörde, iki uygulamada da)
Giriş: `admin@sonar.local`. Her adımdan sonra rakamları kontrol et.
1. **Satış faturası:** Acme'ye 3 adet ürün, %10 iskonto, %20 KDV → kes. Beklenen: stok 3 düşer, Acme bakiyesi toplam kadar artar, numara `SF-...`.
2. **Kısmi tahsilat:** aynı faturaya toplamın yarısı tahsilat → fatura "kısmi", kasa bakiyesi artar, Acme bakiyesi azalır.
3. **Alış faturası:** tedarikçiden alış → stok artar, ortalama maliyet güncellenir.
4. **İptal:** satış faturasını iptal et (ödenmişse önce tahsilatı iptal) → stok/bakiye eski haline döner.
5. **Gider (projeli):** projeye gider yaz → hesap azalır, proje maliyeti ve disiplin kırılımı artar.
6. **Transfer:** kasadan bankaya → iki bakiye toplamı değişmez.
7. **Stok sayım:** sayım farkı → `adjust` hareketi.
8. **Çevrimdışı:** internet kesik iken cari/ürün ekle → bağlanınca kuyruktan eşitlenir; finansal işlem (fatura kesme/tahsilat) çevrimdışıyken **reddedilir**.
9. **Telefon ↔ bilgisayar:** birinde yaz, diğerinde görünsün.
10. **Yedek:** yedek al → `recalc.js` farkı 0.
11. **Yetki:** `calisan@sonar.local` ile yetkisiz ekranlar/işlemler kapalı mı?
