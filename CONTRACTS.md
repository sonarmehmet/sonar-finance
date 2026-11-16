# CONTRACTS — Sözleşme Sürümü

**Güncel: v1.0.1** (2026-11-16)

Sözleşme = `docs/02-firestore-modeli.md` + `docs/04-islem-akislari.md` + `firebase/firestore.rules` + `shared/*.json`.
Yalnız **Ajan 1** değiştirir. Değişirse buraya kayıt düşülür; Android ve Windows uygulamaları bu sürüme uyar.

## Değişiklik kaydı
| Sürüm | Tarih | Değişiklik | Etkilenen |
|---|---|---|---|
| 1.0.1 | 2026-11-16 | Faturaya `rev` alanı (taslak çakışma sayacı); sayaç ilk oluşturma kuralı (04 §3); yerel önbellek = Firestore kalıcı önbelleği (SQLite yok, 05) | invoices, issueInvoice |
| 1.0.0 | 2026-11-16 | İlk sözleşme: parties, products, warehouses, stock_levels, invoices(lines gömülü), payments, accounts, expenses, projects, stats, txns; kural seti | tüm |

## Değişmez kurallar (uygulamalar uymak zorunda)
1. Para tam sayı kuruş, miktar 1/1000, oran baz puan; float yok.
2. Her finansal işlem `txId` ile, `04`'teki adımlarla, tek transaction'da.
3. Bakiye alanları yalnız hareket belgesiyle birlikte değişir.
4. Finansal kayıt silinmez; iptal = ters kayıt.
5. Çevrimdışıyken yalnız taslak kaydedilir.
6. Metinler `shared/l10n/tr.json`'dan, renkler `shared/design-tokens.json`'dan; kodda sabit renk/metin yazma.
