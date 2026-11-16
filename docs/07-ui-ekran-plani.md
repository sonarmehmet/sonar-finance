# 07 — UI Ekran Planı (Windows + Android)

Kaynak: kullanıcı UI/UX talimatı. Renk/ölçü: `shared/design-tokens.json`, metin: `shared/l10n/tr.json`. Kodda sabit renk/metin yok. **Tüm örnek veriler DEMO'dur; üretimde sürekli sahte veri gösterilmez** (boş durum ekranı gösterilir).

## 0. Ortak kurallar
- Koyu tema, kart köşe yarıçapı 12, hafif gölge, neon yok. Aktif/ana buton turkuaz (`accent`).
- Para: `tr-TR`, `₺` sonda ya da başta tutarlı (ör. `1.250,00 ₺`), sağa hizalı, tabular rakam. Pozitif/alacak yeşil, negatif/borç kırmızı, bekleyen turuncu.
- Her liste: arama, filtre, sıralama, sayfalama (25), boş/yükleniyor/hata görünümü. İşlem sonucu: başarı/hata bildirimi. Silme/iptal/ters kayıt: onay penceresi.
- Bağlantı durumu rozeti her zaman görünür (bkz. 05).
- Önemli işlem ≤ 3 tık.

## 1. Windows
**Pencere**: min 1280×720; 1366×768, 1920×1080 test edilir. **Sol menü** 250 px (daralınca 72 px, yalnız ikon), gruplar çizgiyle ayrılır, aktif öğe turkuaz sol çizgi/arka plan. Üst çubuk 64 px: başlık + breadcrumb, tarih aralığı, genel arama (cari/fatura/proje/işlem), bildirim, profil menüsü, **Hızlı İşlem** (Yeni Fatura, Tahsilat, Gider, Stok Girişi).

**Menü (sırayla)**: Genel Bakış · Faturalar · Cari Hesaplar · Kasa ve Banka · Gelir ve Gider · Projeler · Stok Yönetimi · Çek ve Senet (ertelendi, pasif öğe) · Raporlar · Belge Arşivi (ertelendi, pasif) · Kullanıcı Yönetimi · Ayarlar.

| Ekran | Yerleşim |
|---|---|
| **Genel Bakış** | Üstte 6 KPI kartı (Toplam Kasa, Banka, Alacak, Borç, Bu Ay Gelir, Bu Ay Gider; başlık, büyük tutar, önceki döneme % değişim, mini trend, tıklayınca modül). Altında 2 sütun: sol aylık gelir-gider grafiği, sağ nakit akışı grafiği. Alt: sol "Son Finansal İşlemler" tablosu (tarih, açıklama, cari, tür, tutar); sağ sekmeli panel Yaklaşan Ödemeler / Yaklaşan Tahsilatlar / Gecikmiş Faturalar (kırmızı, sakin). En altta proje özeti şeridi (aktif proje, toplam bedel, maliyet, tahsilat, kârlılık). Veri: `stats/summary` + sınırlı sorgular. |
| **Faturalar** | Sekmeler: Tüm · Satış · Alış · İade · Taslaklar. Sağ üstte "Yeni Fatura Oluştur". Filtre çubuğu: arama, tarih, cari, proje. Tablo: Fatura No, Tarih, Cari, Proje, Tür, KDV Dahil Toplam, Ödenen, Kalan, Vade, Durum (renkli etiket), İşlemler (görüntüle, tahsilat/ödeme, PDF, iptal). |
| **Yeni Fatura** | 3 bölüm: (1) Fatura bilgileri (tür, cari, numara [kesilince atanır], tarih, vade, proje, maliyet disiplini, açıklama, "fiyatlar KDV dahil"); (2) Kalem tablosu (ürün/hizmet, açıklama, miktar, birim, birim fiyat, iskonto %, KDV %, depo, satır toplamı) + "Satır Ekle"; (3) sağ altta sabit toplam kutusu (ara toplam, iskonto, KDV, genel toplam). Alt çubuk: Taslak Kaydet · Faturayı Kaydet (kes) · Yazdır/PDF. Toplamlar canlı hesaplanır (04 §2). |
| **Fatura Detay** | Başlık + durum, kalemler, toplamlar, ödeme geçmişi, "Tahsilat/Ödeme Ekle", "İptal Et" (ödemesi varsa pasif + açıklama). |
| **Cari Hesaplar** | Sol liste (firma, tür, telefon, borç, alacak, net) + "Yeni Cari"; sağ detay: firma adı + büyük bakiye; sekmeler Genel Bakış · Hesap Hareketleri (tarih, açıklama, borç, alacak, bakiye — ekstre) · Faturalar · Tahsilatlar · Ödemeler. |
| **Kasa ve Banka** | Üstte toplam nakit + banka; hesap kartları (ad, tür, bakiye, son hareket); kart seçilince hareket geçmişi. Butonlar: Para Girişi · Para Çıkışı · Hesaplar Arası Transfer · Yeni Kasa · Yeni Banka Hesabı. Transfer gelir/gider sayılmaz. |
| **Gelir ve Gider** | Sekmeler Gelirler / Giderler; gider ekleme hızlı form (tutar, kategori, hesap, cari?, proje?, disiplin?, tarih). |
| **Projeler** | Proje kartları ızgarası (ad, müşteri, tarihler, sözleşme, tahsilat, harcama, kalan alacak, tahmini/gerçekleşen kâr). Detay: üst özet; sekmeler Genel Bakış · Gelirler · Giderler · Malzeme · İşçilik · Taşeronlar · Tahsilatlar · Belgeler (pasif) · Raporlar. Disiplin bazlı bütçe/gerçekleşen/kalan + bütçe-gerçekleşen grafiği. |
| **Stok Yönetimi** | Üst: toplam ürün, toplam stok değeri, kritik stok sayısı. Sekmeler: Ürünler · Depolar · Hareketler. Ürün tablosu: kod, ad, kategori, birim, miktar, birim maliyet, toplam değer, depo, kritik seviye. Eylemler: Stok Girişi, Stok Çıkışı, Sayım Düzeltme, Depolar Arası Transfer, Yeni Ürün, Yeni Depo. |
| **Raporlar** | Filtreler (tarih, proje, cari, tür) + rapor listesi: aylık/yıllık gelir-gider, kasa, banka, cari ekstre, borç-alacak, KDV özeti, proje maliyet, proje kârlılık, stok değer, tahsilat, ödeme. PDF/Excel dışa aktar. |
| **Kullanıcı Yönetimi** | Kullanıcı listesi, rol, izin anahtarları (invoice/party/stock/finance/project), aktif/pasif. |
| **Ayarlar** | Şirket bilgisi, fatura ön ekleri, KDV varsayılanı, negatif stok izni, Senkronizasyon kuyruğu, Yedekleme (06), Yeniden hesapla (yönetici). |
| **Giriş** | E-posta + şifre, hata mesajı, "Beni hatırla" (güvenli depolama). |

## 2. Android
**Üst bar**: logo, bildirim, profil. **Alt menü (5)**: Ana Sayfa · İşlemler · Projeler · Raporlar · Profil. Diğer modüllere **İşlemler** üzerinden ulaşılır (Faturalar, Cari, Kasa/Banka, Gider, Stok). Tablo yok; kart + yatay kaydırılan bilgi şeritleri. Başparmak bölgesi: ana eylemler altta. Klavye açılınca form alanları örtülmez (`resizeToAvoidBottomInset`, kaydırılabilir form).

| Ekran | Yerleşim |
|---|---|
| **Ana Sayfa** | Büyük toplam bakiye kartı (kasa+banka). Altında 4 özet çipi: Alacak, Borç, Gelir, Gider (yatay kaydırma). **Hızlı İşlem** 4 büyük buton: Fatura · Tahsilat · Gider · Proje. Aşağıya doğru Son İşlemler listesi. Gecikmiş fatura uyarı kartı (varsa). |
| **İşlemler** | Üstte bölüm sekmeleri/ızgara: Faturalar, Cari, Kasa/Banka, Gider, Stok. Seçilen bölümün listesi: arama + filtre çipleri + kartlar. FAB: yeni kayıt. |
| **Fatura Listesi** | Kart: no, cari, tutar, kalan, vade, durum etiketi. Filtre çipleri: Tümü/Satış/Alış/İade/Taslak. |
| **Hızlı Fatura** | Adım adım: (1) tür+cari, (2) kalemler (ürün seç/barkod okut, miktar, fiyat), (3) özet + kaydet. Kısa formlar; alt sabit "Taslak" / "Kaydet" butonları. |
| **Tahsilat/Ödeme** | Cari seç → hesap → tutar → faturalara otomatik/elle dağıt → kaydet. |
| **Hızlı Gider** | Tutar, kategori, hesap, proje (ops.), foto (ertelendi). |
| **Cari Detay** | Üstte bakiye, altında Hareketler/Faturalar/Tahsilat sekmeleri, kart satırlar. |
| **Stok** | Ürün kartları (ad, miktar, depo, kritik rozeti), stok giriş/çıkış butonları, barkod arama. |
| **Projeler** | Proje kartları; detayda özet + disiplin bütçe çubukları. |
| **Raporlar** | Rapor kartları; tarih filtresi; PDF paylaş. |
| **Profil** | Kullanıcı, bağlantı/senkron durumu + kuyruk, yedek bilgisi (yalnız yönetici), çıkış. |

## 3. Navigasyon şeması
```
Giriş → (başarılı) → Kabuk
Windows: Kabuk[Sidebar+Topbar] → /overview | /invoices(/new,/:id) | /parties(/:id) | /cash-bank(/:id)
         | /income-expense | /projects(/:id) | /stock(/products,/warehouses,/movements)
         | /reports | /users | /settings(/sync,/backup)
Android: Kabuk[BottomNav] → /home | /transactions(/invoices,/parties,/cash-bank,/expenses,/stock)
         | /projects(/:id) | /reports | /profile ;  modal/tam ekran: /invoices/new, /payments/new, /expenses/new
```

## 4. Ortak bileşenler
`AppShell/Sidebar/Topbar/BottomNav`, `KpiCard`, `MoneyText` (işaret rengi), `StatusChip`, `DataTable`(Windows) / `ListCard`(Android), `FilterBar`, `DateRangePicker`, `SearchField`, `PartyPicker`, `ProductPicker`, `AccountPicker`, `InvoiceLinesEditor`, `TotalsBox`, `ConfirmDialog`, `Toast`, `EmptyState`, `LoadingState`, `ErrorState`, `ConnectionBadge`, `Chart` (çizgi/sütun/çubuk), `Pagination`.

## 5. Teknoloji önerileri
- **Windows**: React Router, TanStack Table, Recharts, lucide-react, CSS değişkenleri (tokens'dan üretilir), `Intl.NumberFormat('tr-TR')`, Inter yazı tipi (yerel dosya, çevrimdışı çalışsın), PDF: `pdf-lib`/`jspdf`, Excel: `exceljs`/`xlsx`.
- **Android**: Riverpod, go_router, fl_chart, `lucide_icons`/benzeri, `google_fonts` yerine **paketlenmiş Inter** (çevrimdışı), `intl` (tr_TR), `mobile_scanner` (barkod), `pdf`+`printing` (PDF), `excel` paketi.
