# 08 — Panel, Rapor ve Hesap Spesifikasyonu (Sözleşme v1.0.3)

İki uygulama aynı sayıları göstermek zorundadır. Tutarlar **KDV hariç** (aksi yazılmadıkça), kuruş cinsindendir. "Bu ay" = `YYYY-MM` (Europe/Istanbul). Tarihler `YYYY-MM-DD` metin.

## 1. `stats/summary` (genel bakış verisi)
```
receivableMinor, payableMinor, cashMinor, bankMinor,
months: { 'YYYY-MM': { incomeMinor, expenseMinor, inMinor, outMinor } },
updatedAt
```
- `incomeMinor` = kesilmiş satış (KDV hariç, `taxable`) − satış iade; `expenseMinor` = alış (KDV hariç) − alış iade + giderler (KDV hariç). Ay anahtarı fatura/gider **tarihinden** (`issueDate`/`date`).
- `inMinor` = o ay (ödeme tarihine göre) tahsilat toplamı; `outMinor` = o ay ödeme toplamı + giderlerden hesaptan çıkan tutar. **Hesaplar arası transfer hiçbirine girmez.**
- İptal/ters kayıt: iptal edilen belgenin etkisi **aynı ayın** toplamından düşülür (ters kayıt işlem tarihine değil, orijinal belge ayına yazılır).
- Güncelleme kuralları `04` §3,§4,§5,§6,§7'de.

## 2. Genel Bakış kartları
| Kart | Değer | Değişim % |
|---|---|---|
| Toplam Kasa | `cashMinor` | — (önceki ay sonu bilinmez; trend yok veya `inMinor-outMinor` kümülatif) |
| Toplam Banka | `bankMinor` | — |
| Toplam Alacak | `receivableMinor` | — |
| Toplam Borç | `payableMinor` | — |
| Bu Ay Gelir | `months[bu ay].incomeMinor` | `(bu - önceki) / önceki × 100`, 1 ondalık; önceki = 0 ise "—" |
| Bu Ay Gider | `months[bu ay].expenseMinor` | aynı |

Mini trend: son 6 ayın ilgili değeri (`months`). Kasa/Banka/Alacak/Borç kartlarında trend yerine yalnız tutar gösterilir.
- Aylık gelir-gider grafiği: son 12 ay `incomeMinor` ve `expenseMinor` (yan yana sütun).
- Nakit akışı grafiği: son 12 ay `inMinor` ve `outMinor` + net (`in-out`) çizgi.
- Net finansal pozisyon: `cashMinor + bankMinor + receivableMinor − payableMinor`.

## 3. Panel listeleri
- **Son finansal işlemler**: `invoices` (status≠draft), `payments`, `expenses` için ayrı `orderBy('createdAt','desc').limit(10)`; istemcide birleştir, `createdAt`'e göre ilk 10. Tür etiketleri: fatura tipi, "Tahsilat", "Ödeme", "Gider".
- **Yaklaşan ödemeler / tahsilatlar**: `invoices where paymentStatus in ['unpaid','partial'] orderBy dueDate limit 100`; istemcide `type`: alış → ödeme, satış → tahsilat; `dueDate` bugünden itibaren 30 gün içinde; iade faturaları hariç. Tutar = `totalMinor − paidMinor`.
- **Gecikmiş**: aynı sorgu, `dueDate < bugün`. Satış gecikmişleri "Gecikmiş Faturalar" kartında, alış gecikmişleri "Yaklaşan Ödemeler" içinde kırmızı satır.
- **Durum etiketi** (fatura): `draft`→Taslak; `void`→İptal; `paid`→Ödendi; `partial`→Kısmi Ödendi (vade geçmişse Gecikmiş); `unpaid`→ vade geçmişse Gecikmiş, değilse Bekliyor.

## 4. Proje hesapları (`project_stats` + `projects`)
- `contractMinor` **KDV hariç** sözleşme bedeli. `budgets` disiplin başına KDV hariç bütçe.
- Tahmini kâr = `contractMinor − Σ budgets`.
- Gerçekleşen maliyet = `costMinor` (KDV hariç alış faturaları + proje giderleri); disiplin kırılımı `byDiscipline`.
- Gerçekleşen kâr = `revenueMinor − costMinor` (`revenueMinor` = KDV hariç satış faturaları, iadeler düşülmüş).
- Kâr marjı % = `gerçekleşen kâr / revenueMinor × 100` (gelir 0 ise "—").
- Kalan bütçe (disiplin) = `budgets[d] − byDiscipline[d]` (negatif = aşım, kırmızı).
- Kalan alacak (proje) = proje satış faturaları `Σ(totalMinor) − collectedMinor`; kalan borç = proje alış faturaları `Σ(totalMinor) − paidOutMinor`. Bu iki değer sorguyla (`invoices where projectId==X`) hesaplanır, saklanmaz.
- Proje özet kartı "tahsilat" = `collectedMinor`, "harcama" = `costMinor`.
- Genel Bakış proje şeridi: aktif proje sayısı, Σ `contractMinor`, Σ `costMinor`, Σ `collectedMinor`, toplam gerçekleşen kâr.

## 5. Cari ekstre
- Sıralama: `date` artan, ardından `createdAt`, ardından `txId`.
- Sütunlar: **Borç** = `deltaMinor > 0` (cari bize borçlandı: satış faturası, bizim yaptığımız ödeme); **Alacak** = `|deltaMinor|` için `deltaMinor < 0` (cari alacaklandı: alış faturası, bizim aldığımız tahsilat). Bakiye sütunu = kümülatif `balanceMinor` (pozitif = bizim alacağımız, yeşil; negatif = borcumuz, kırmızı).
- Açılış bakiyesi (tarih aralığının başı) = `party.balanceMinor − Σ delta(date ≥ başlangıç)`. Kapanış = `party.balanceMinor − Σ delta(date > bitiş)`.
- Cari listesindeki "Borç"/"Alacak": `balance < 0` → Borç sütununda `|balance|`; `balance > 0` → Alacak sütununda.

## 6. Raporlar (tümü PDF + Excel)
| Rapor | Kaynak | Sütunlar / içerik |
|---|---|---|
| Aylık gelir-gider | `stats.months` | ay seçimi: gelir, gider, net; iki ay karşılaştırma |
| Yıllık gelir-gider | `stats.months` | 12 ay tablo + toplam |
| Kasa raporu | `account_movements` (hesap `type=cash`) | tarih, açıklama (refType), giriş, çıkış, bakiye; açılış/kapanış |
| Banka raporu | aynı, `type=bank` | aynı |
| Cari ekstre | §5 | tarih, açıklama, borç, alacak, bakiye |
| Borç-alacak | `parties` | firma, tür, alacak, borç, net; toplamlar |
| KDV özeti | `invoices`, `expenses` (ay/aralık) | Hesaplanan KDV = satış KDV − satış iade KDV; İndirilecek KDV = alış KDV − alış iade KDV + gider KDV; Ödenecek/Devreden = hesaplanan − indirilecek; oran kırılımı |
| Proje maliyet | `project_stats`, `projects` | disiplin, bütçe, gerçekleşen, kalan, % |
| Proje kârlılık | §4 | proje, sözleşme, gelir, maliyet, tahmini/gerçekleşen kâr, marj |
| Stok değer | `products`, `stock_levels` | ürün, depo, miktar, ortalama maliyet, değer = `qtyMilli × avgCostMinor / 1000` (yuvarlı), toplam |
| Tahsilat raporu | `payments direction=in` (aralık) | tarih, cari, hesap, yöntem, tutar, dağıtılan faturalar |
| Ödeme raporu | `payments direction=out` | aynı |
Ortak filtreler: tarih aralığı, proje, cari, işlem türü. İptal edilmiş belgeler varsayılan olarak **hariç** (seçenekle dahil, "İptal" etiketiyle).
Excel: ilk sayfa özet, ikinci sayfa detay; para hücreleri sayı (kuruş/100, 2 ondalık), `tr-TR` biçim. PDF: başlık (şirket, rapor adı, aralık, oluşturma zamanı), sayfa numarası.

## 7. Tutarlılık kontrolü (Ayarlar → Yönetici)
Uygulama **salt-okunur denetim** yapar: 
- `party.balanceMinor` = Σ `ledger_entries.deltaMinor`; `account.balanceMinor` = Σ `account_movements.deltaMinor`; `stock_levels.qtyMilli` = Σ `stock_movements.deltaMilli`; `product.totalQtyMilli` = Σ seviyeler; `invoice.paidMinor` = Σ aktif ödeme dağılımları.
- Fark varsa listeler. **Düzeltme** kurallar gereği uygulamadan yapılamaz; `firebase/tools/recalc.js --fix` (yönetici servis anahtarı, bkz. 06) ile yapılır.
