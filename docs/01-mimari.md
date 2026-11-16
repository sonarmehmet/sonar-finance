# 01 — Mimari

```
Android (Flutter, Riverpod, GoRouter)   Windows (React, TS, Vite, Tauri 2)
              \                                   /
               Firebase Auth + Cloud Firestore (Spark / ücretsiz)
```
- Tek gerçek kaynak: Firestore. Ayrı üretim veritabanı yok.
- **Cloud Functions ve Cloud Storage yok** (Blaze gerektirir). Finansal mantık istemcide transaction ile çalışır; `firestore.rules` bakiye değişimlerini hareket belgesiyle çapraz doğrular (bkz. 03, 04).
- Belge/fotoğraf arşivi ilk sürümde yok. Fatura PDF'i yerelde üretilir.
- Para tam sayı kuruş. Bkz. 02 ve 04.
- İşlem mantığı iki dilde (Dart, TS) yazılır; tek referans `docs/04-islem-akislari.md`.
- Tasarım sistemi: `shared/design-tokens.json`, metinler: `shared/l10n/tr.json`, sabitler: `shared/constants.json`.

## Katmanlar (her iki uygulamada aynı isimler)
1. `core/` — tema, router, firebase başlatma, para/tarih yardımcıları, hata tipleri.
2. `data/` — modeller (02'ye birebir), repository'ler (okuma/sorgu).
3. `services/` (Android: `data/islem_servisleri`) — **işlem servisleri**: `issueInvoice, cancelInvoice, recordPayment, cancelPayment, transferBetweenAccounts, recordExpense, adjustStock, transferStock`. Hepsi 04'teki adımları uygular. UI doğrudan Firestore'a yazmaz.
4. `features/` — ekranlar (modül başına klasör).

## Ortam
- Geliştirme: Firebase Emulator (`scripts/run_emulator.bat`, proje kimliği `demo-sonar-finance`).
- Üretim: gerçek Firebase projesi (`firebase/.firebaserc` içinde `default` değiştirilir); ilk yönetici `users/{uid}` belgesi konsoldan elle oluşturulur (bkz. 03).
