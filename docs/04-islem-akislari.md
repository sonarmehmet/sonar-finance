# 04 — İşlem Akışları (TEK REFERANS — Dart ve TypeScript birebir uymalı)

Cloud Functions yok. Her finansal işlem istemcide **tek bir `runTransaction`** (veya tüm yazmalar tek `WriteBatch`) olarak çalışır.
Firestore kuralı: transaction içinde **önce tüm okumalar, sonra yazmalar**. Kurallar (`firestore.rules`) bakiye değişimlerini hareket belgesiyle çapraz doğrular.

## 1. Ortak adımlar
1. Form açılınca `txId = uuidv4()` üret. Aynı form yeniden gönderilirse **aynı txId** kullanılır → ikinci denemede `txns/{txId}` zaten vardır, işlem reddedilir (çift kayıt yok).
2. Transaction: `txns/{txId}` oku → varsa "zaten işlendi" de, bitir.
3. Gerekli belgeleri oku, doğrula (yetki, durum, stok, tutar).
4. Yaz: asıl belge + bakiye alanları (`lastTxId = txId`) + hareket belgeleri (`ledger_entries`, `account_movements`, `stock_movements`) + `stats/summary` + `txns/{txId}` + `audit_logs/{uuid}`.
5. Çevrimdışıyken **kesinleştirme yapılmaz**; yalnızca taslak kaydedilir (bkz. 05).

## 2. Para hesabı (tam sayı)
Yuvarlama: `roundHalfUp(a / b)` = `(2*a + b) / (2*b)` tam sayı bölme (a ≥ 0). Negatifler için `sign * roundHalfUp(|a|/b)`.

Satır (KDV hariç fiyat, `priceIncludesVat=false`):
```
net      = roundHalfUp(qtyMilli * unitPriceMinor / 1000)
discount = roundHalfUp(net * discountBp / 10000)
taxable  = net - discount
vat      = roundHalfUp(taxable * vatBp / 10000)
total    = taxable + vat
```
Satır (KDV dahil fiyat, `priceIncludesVat=true`):
```
grossBeforeDisc = roundHalfUp(qtyMilli * unitPriceMinor / 1000)
discIncl        = roundHalfUp(grossBeforeDisc * discountBp / 10000)
total           = grossBeforeDisc - discIncl
taxable         = roundHalfUp(total * 10000 / (10000 + vatBp))
vat             = total - taxable
net             = roundHalfUp(grossBeforeDisc * 10000 / (10000 + vatBp))   // KDV hariç, iskonto öncesi
discount        = net - taxable                                            // KDV hariç iskonto
```
Her iki modda da `net - discount = taxable` ve `taxable + vat = total` geçerlidir. Referans uygulama ve test vektörleri: `shared/reference/invoice_calc.py`, `shared/test-vectors/invoice-calc.json` (Dart ve TS çıktıları bunlarla birebir eşleşmeli).

Başlık toplamları satırların toplamıdır (ayrıca yuvarlama yok):
`subtotalMinor = Σ net`, `discountMinor = Σ discount`, `vatMinor = Σ vat`, `totalMinor = Σ total`.
Örnek: 3 adet × 1.250,00 TL, iskonto %10, KDV %20 → `qtyMilli=3000, unitPriceMinor=125000` → net 375000, discount 37500, taxable 337500, vat 67500, total 405000.

## 3. Faturayı kes (`issueInvoice`)
Girdi: taslak veya yeni fatura, `txId`.
- Okunacaklar: cari, `counters/invoice_{type}`, her stok takipli satır için `products/{id}` ve `stock_levels/{pid}_{wh}`, `stats/summary`, `projects`/`project_stats` (varsa).
- Doğrula: durum `draft`/yeni; taslaktan kesiliyorsa ekrandaki `rev` ile sunucudaki `rev` aynı olmalı (05); en az 1 satır; toplamlar §2 ile yeniden hesaplanır (istemci değeri değil, **hesaplanan** yazılır); `dueDate >= issueDate`; stok takipli satırda `warehouseId` zorunlu; `allowNegativeStock=false` iken çıkış stoğu aşmamalı.
- Numara: `counters/invoice_{type}` yoksa `create` ile `last=1`, varsa `last += 1` (kurallar yalnız bu iki değere izin verir). Numara `counters.last` → `"{prefix}-{yıl}-{last 6 hane}"`.
- Etki işareti `s`: `sales:+1, purchase:-1, sales_return:-1, purchase_return:+1` (cari bakiyeye).
  - `party.balanceMinor += s * totalMinor`; `ledger_entries/{txId}_{partyId}` (`deltaMinor = s*totalMinor`, `refType='invoice'`).
- Stok yönü: `sales: çıkış, purchase: giriş, sales_return: giriş, purchase_return: çıkış`.
  - Her stok takipli satır için `stock_levels.qtyMilli ±= qtyMilli`, `products.totalQtyMilli` aynı, `stock_movements/{txId}_{levelId}` (aynı ürün+depo birden çok satırda ise **tek harekette birleştir**).
  - Ortalama maliyet (yalnız `purchase` girişi): `newAvg = roundHalfUp((oldQty*oldAvg + inQty*unitCost) / (oldQty+inQty))` (KDV hariç birim maliyet = `taxable*1000/qtyMilli` yuvarlı). Satış çıkışında `unitCostMinor = avgCostMinor` (hareket kaydına yazılır, avg değişmez).
- `invoices`: `status='issued'`, `number`, `paidMinor=0`, `paymentStatus='unpaid'`, `txId`, `lastTxId`.
- Proje: `projectId` varsa `project_stats`: `sales → revenueMinor += taxable`, `purchase → costMinor += taxable` ve `byDiscipline[costCategory] += taxable` (iadeler tersi).
- `stats/summary`: alacak/borç toplamı, eski ve yeni cari bakiyenin pozitif/negatif katkısı farkıyla güncellenir (§8).

## 4. Faturayı iptal et (`cancelInvoice`)
- Şart: `status=='issued'` ve `paidMinor == 0` (önce ödemeler iptal edilmeli).
- Kes işleminin **tam tersi**: cari `−s*total`, ledger ters kayıt (`refType='reversal'`), stok ters hareket, proje istatistiği ters.
- `status='cancelled'`, `cancelTxId`. Eski kayıtlar silinmez/değişmez.
- Stok geri alımında yeterlilik: kesilmiş alış faturası iptali çıkış yaratır → stok yetersizse reddet.

## 5. Tahsilat / ödeme (`recordPayment`)
Girdi: `direction ('in' tahsilat | 'out' ödeme)`, `partyId`, `accountId`, `amountMinor > 0`, `date`, `method`, `allocations[{invoiceId, amountMinor}]`.
- Doğrula: Σ allocations ≤ amount; her fatura `issued`, cari aynı, yön uyumlu (`in` ↔ sales/purchase_return, `out` ↔ purchase/sales_return), `allocation ≤ remaining (total - paid)`.
- `unallocatedMinor = amount - Σ allocations` (avans; cari bakiyede yine etkili).
- Hesap: `in → account.balanceMinor += amount`, `out → -= amount`; `account_movements/{txId}_{accountId}`.
- Cari: `in → party.balanceMinor -= amount`; `out → += amount`; `ledger_entries/{txId}_{partyId}`.
- Faturalar: `paidMinor += allocation`; `paymentStatus = paid` (paid==total) / `partial` / `unpaid`; `lastTxId`.
- Proje: faturanın `projectId`'si için `collectedMinor` (in) / `paidOutMinor` (out) artar.
- `stats/summary`: `cashMinor`/`bankMinor`, alacak/borç.

## 6. Ödemeyi iptal et (`cancelPayment`)
`status='cancelled'`, `cancelTxId`; hesap, cari, fatura `paidMinor/paymentStatus`, proje istatistiği ters; ters hareket belgeleri (`refType='reversal'`). Hesap bakiyesi eksiye düşecekse reddetme **zorunlu değil**, uyarı göster.

## 7. Diğer işlemler
- **Hesaplar arası transfer**: iki `account_movements` (`transfer_out`/`transfer_in`), iki hesap bakiyesi, gelir/gider **değil**. Hesap ID'leri farklı olmalı.
- **Gider (`recordExpense`)**: `expenses` + hesap azalır (`kind='expense'`) + `stats.months[ay].expenseMinor += amount` + proje varsa `costMinor += amount - vat`, `byDiscipline[discipline]`.
- **Gelir kaydı (cari dışı)**: ileride; ilk sürümde gelir = satış faturası + tahsilat.
- **Stok sayımı/düzeltme (`adjustStock`)**: `adjust` hareketi, fark kadar; neden zorunlu.
- **Depolar arası transfer**: `transfer_out` + `transfer_in`, ortalama maliyet değişmez.
- **Açılış stoğu**: `opening` hareketi + `avgCostMinor` set.
- **Açılış bakiyesi (cari/hesap)**: `refType='opening'` hareketi ile.

## 8. Özet istatistik (`stats/summary`)
Katkı fonksiyonu: `recv(b) = max(b,0)`, `pay(b) = max(-b,0)`. Bir cari bakiyesi `old→new` olunca `receivableMinor += recv(new)-recv(old)`, `payableMinor += pay(new)-pay(old)`.
Aylık gelir = o ay kesilen `sales` (iade düşülür) KDV hariç toplamı; aylık gider = `purchase` KDV hariç + `expenses` KDV hariç. Ay anahtarı `issueDate`/`date` içinden `YYYY-MM`.
Tutarsızlık şüphesi: "yeniden hesapla" aracı (ayarlar → yönetici) tüm cari/hesap/fatura belgelerini okuyup `stats/summary`'yi sıfırdan yazar (F5).

## 9. Hata ve onay
Başarı: yeşil bildirim + belge numarası. Hata: nedenle birlikte kırmızı bildirim (ör. "Depo A'da yetersiz stok: Vana DN50 (kalan 2)"). İptal ve ters kayıt işlemlerinden önce onay penceresi.

## 10. Yetki eşlemesi
`issueInvoice/cancelInvoice → invoice.write` · `recordPayment/cancelPayment/transfer/expense → finance.write` · `adjustStock/transfer/opening → stock.write` · cari/ürün/depo/proje ana verisi → `party.write`/`stock.write`/`project.write`.
