# 02 — Firestore Veri Modeli (Sözleşme v1.0.0)

Tek şirket, Spark planı (Cloud Functions yok). Tüm iş verisi `companies/{cid}/...` altındadır. `cid` sabit tek şirket olsa bile yapı çok şirkete hazırdır.
Her belgede `companyId` alanı bulunur (yedek/dışa aktarma için); kurallar `companyId == cid` zorlar.

## Genel kurallar
- **Para**: tam sayı kuruş (`...Minor`). Float yok. Varsayılan `TRY`.
- **Miktar**: tam sayı, 1/1000 birim (`...Milli`). 2,5 adet = `2500`.
- **Oranlar**: baz puan (`...Bp`). %20 = `2000`, %12,5 = `1250`.
- **İş tarihleri**: `"YYYY-MM-DD"` metin (saat dilimi sorunu yok, sıralanabilir). Sistem zamanları `Timestamp`.
- **Bakiye işareti (cari)**: `balanceMinor > 0` → bize borçlu (**alacak**), `< 0` → biz borçluyuz (**borç**).
- **ID'ler**: istemci üretir (UUID v4, küçük harf). Hareket belgeleri bileşik ID kullanır: `{txId}_{konuId}`.
- **Silme yok**: finansal belgeler silinmez; iptal edilir (ters kayıt). Ana veriler `active=false` yapılır.
- Spark kotası: gereksiz canlı dinleyici açma, listelerde `limit` + sayfalama kullan.

## Kök koleksiyonlar
| Yol | Alanlar |
|---|---|
| `users/{uid}` | `companyId, displayName, email, role('admin'\|'employee'), permissions{map<string,bool>}, active, createdAt` |
| `companies/{cid}` | `name, taxNo, taxOffice, address, phone, currency('TRY'), schemaVersion, settings{allowNegativeStock(false), defaultVatBp(2000), invoicePrefix{sales:'SF',purchase:'AF',sales_return:'SI',purchase_return:'AI'}}` |

Yetki anahtarları: `invoice.write`, `party.write`, `stock.write`, `finance.write`, `project.write`. `admin` hepsine sahiptir. Okuma: aktif her şirket kullanıcısı.

## `companies/{cid}/` altı
| Koleksiyon / ID | Alanlar |
|---|---|
| `parties/{partyId}` (cari) | `companyId, kinds['customer'\|'supplier'], name, taxOffice, taxNo, phone, email, address, notes, balanceMinor, lastTxId, active, createdAt, updatedAt` |
| `products/{productId}` | `companyId, code, name, category, unit, vatBp, trackStock, buyPriceMinor, sellPriceMinor, avgCostMinor, totalQtyMilli, minStockMilli, barcode, active, createdAt, updatedAt` |
| `warehouses/{whId}` | `companyId, name, location, isDefault, active` |
| `stock_levels/{productId}_{whId}` | `companyId, productId, warehouseId, qtyMilli, lastTxId` |
| `stock_movements/{txId}_{levelId}` | `companyId, txId, productId, warehouseId, deltaMilli, type('opening'\|'purchase_in'\|'sale_out'\|'return_in'\|'return_out'\|'adjust'\|'transfer_in'\|'transfer_out'), unitCostMinor, refType, refId, date, createdBy, createdAt` |
| `invoices/{invoiceId}` | bkz. aşağı |
| `payments/{paymentId}` | `companyId, txId, direction('in'\|'out'), partyId, accountId, amountMinor, date, method('cash'\|'bank_transfer'\|'cheque'\|'card'), allocations[{invoiceId, amountMinor}], unallocatedMinor, projectId?, note, status('active'\|'cancelled'), cancelTxId?, createdBy, createdAt` |
| `accounts/{accountId}` (kasa+banka) | `companyId, type('cash'\|'bank'), name, bankName, iban, currency, balanceMinor, lastTxId, active` |
| `account_movements/{txId}_{accountId}` | `companyId, txId, accountId, deltaMinor, kind('in'\|'out'\|'transfer_in'\|'transfer_out'\|'expense'), refType, refId, date, createdAt` |
| `ledger_entries/{txId}_{partyId}` | `companyId, txId, partyId, deltaMinor, refType('invoice'\|'payment'\|'reversal'\|'opening'), refId, description, date, createdAt` |
| `expenses/{expenseId}` | `companyId, txId, categoryId, amountMinor (KDV dahil), vatMinor, accountId, partyId?, projectId?, discipline?, date, description, status('active'\|'cancelled')` |
| `expense_categories/{id}`, `income_categories/{id}` | `companyId, name, kind, active` |
| `projects/{projectId}` | `companyId, name, partyId (müşteri), location, startDate, endDate, contractMinor, status('active'\|'done'\|'paused'), budgets{<discipline>: minor}, notes` |
| `project_stats/{projectId}` | `revenueMinor, costMinor, collectedMinor, paidOutMinor, byDiscipline{<discipline>: costMinor}, lastTxId` |
| `stats/summary` | `receivableMinor, payableMinor, cashMinor, bankMinor, months{'YYYY-MM': {incomeMinor, expenseMinor, inMinor, outMinor}}, updatedAt` |
| `counters/{name}` | `last` (int). Adlar: `invoice_sales, invoice_purchase, invoice_sales_return, invoice_purchase_return` |
| `txns/{txId}` | `companyId, type, createdBy, createdAt, refs{}` — **idempotency + denetim çapası** |
| `audit_logs/{id}` | `companyId, action, entityType, entityId, userId, at, summary` — yalnızca `create` |

### Fatura belgesi (`invoices/{invoiceId}`)
```
companyId, type ('sales'|'purchase'|'sales_return'|'purchase_return'),
status ('draft'|'issued'|'cancelled'), number (issued olunca atanır; ör. SF-2026-000001),
partyId, partyName (anlık kopya), projectId?, costCategory? (proje maliyet disiplini),
issueDate, dueDate, currency ('TRY'), fx? (ayrılmış: {currency, amountMinor, rateMicro}),
priceIncludesVat (bool), note,
lines: [{ lineId, productId?, description, qtyMilli, unit, unitPriceMinor, discountBp, vatBp,
          warehouseId?, netMinor, discountMinor, vatMinor, totalMinor }],
subtotalMinor, discountMinor, vatMinor, totalMinor,
paidMinor, paymentStatus ('none' taslak | 'unpaid' | 'partial' | 'paid' | 'void' iptal),
rev (taslak düzenleme sayacı, her kayıtta +1; bkz. 05),
txId? (kesme işlemi), cancelTxId?, lastTxId, createdBy, createdAt, updatedAt
```
Gösterim durumu (istemcide türetilir): `draft→Taslak`, `paid→Ödendi`, `partial→Kısmi Ödendi` (vade geçmişse `Gecikmiş`), `unpaid` ve vade geçmişse `Gecikmiş`, aksi halde `Bekliyor`; `void→İptal`. Vadesi gelen sorgusu `paymentStatus in ['unpaid','partial']` taslak ve iptalleri kendiliğinden dışlar.

## Önerilen sorgular (indexler `firebase/firestore.indexes.json` içinde)
- Fatura listesi: `type`, `issueDate desc`, `limit 25`.
- Cari ekstre: `ledger_entries where partyId == X order by date`.
- Vadesi gelen: `invoices where paymentStatus in [unpaid, partial] order by dueDate`.
- Stok hareketi: `stock_movements where productId == X order by date desc`.

## Sözleşmeden sapmalar (master prompt'a göre)
- `customers` + `suppliers` → tek `parties` (bir cari hem müşteri hem tedarikçi olabilir).
- `invoice_items` → fatura belgesi içinde `lines[]`.
- `collections` + `payments` → tek `payments` (`direction`).
- `cash_accounts` + `bank_accounts` → tek `accounts` (`type`).
- `accounting_entries` → `ledger_entries` (cari yevmiye); çift taraflı genel muhasebe kapsam dışı.
- Ertelenen: `cheques, promissory_notes, documents, payment_schedules, contacts, bank_transactions`.
