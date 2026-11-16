# 06 — Yedekleme ve Geri Yükleme

Spark planında Firestore'un yönetilen dışa aktarması (GCS) **yok**. Strateji: yönetici yetkisiyle tüm şirket verisini **JSON dosyasına** dışa aktarmak.

## Yedek alma
- Uygulamada: Ayarlar → Yedekleme → **Yedek Al** (yalnız `admin`). Okunan koleksiyonlar: `companies/{cid}` + tüm alt koleksiyonlar (`parties, products, warehouses, stock_levels, stock_movements, invoices, payments, accounts, account_movements, ledger_entries, expenses, expense_categories, income_categories, projects, project_stats, stats, counters, txns, audit_logs`) ve şirkete ait `users`.
- Çıktı: `sonar-backup-YYYYMMDD-HHmm.json` (+ isteğe bağlı **şifreli** `.json.enc`: AES-256-GCM, anahtar scrypt/PBKDF2 ile parolayı türetir).
- Maliyet: okunan belge sayısı kadar okuma (kota: 50.000/gün). Büyük veride bir günde tamamlanmazsa kaldığı yerden devam eden sayfalama kullan.
- Yedek geçmişi: her yedekte `audit_logs` kaydı (`action='backup.export'`, dosya adı, belge sayısı); ayrıca uygulama yerelde son 20 yedeğin adını/tarihini listeler.
- Önerilen sıklık: haftalık + büyük işlemlerden önce; dosyayı bulut sürücü/harici diske kopyala (Firebase dışında).
- Format: tüm tarihler (`Timestamp`) `{"__ts":{"s":<saniye>,"n":<nanosaniye>}}` olarak yazılır; aksi her değer düz JSON.

## Geri yükleme
- **Uygulamadan geri yükleme yok** (yıkıcı işlem). Komut satırı araçları: `firebase/tools/export.js` ve `firebase/tools/restore.js` (Node, `firebase-admin`).
- `restore.js` güvenceleri: varsayılan olarak yalnız **emülatöre** yazar; gerçek projeye yazmak için `--production --i-know-what-i-am-doing`; hedefte `companies/{cid}` doluysa `--force` olmadan durur.
- Geri yükleme sonrası: `stats/summary` "yeniden hesapla" (F5) ile doğrulanır; cari bakiyeleri `ledger_entries` toplamıyla, hesap bakiyeleri `account_movements` toplamıyla, stok `stock_movements` toplamıyla karşılaştırılır.
- **Test zorunlu (F7)**: emülatörde seed → işlemler → export → emülatörü sıfırla → restore → doğrulama farkı = 0. Test edilmeden yedek özelliği "tamam" sayılmaz.

## Rapor dışa aktarma
Excel/PDF raporları F5'te (Windows: tarayıcı tarafında üretim; Android: paylaşım menüsü). Raporlar yedek yerine geçmez.

## Belgeler
Cloud Storage yok; belge arşivi ertelendi. Fatura PDF'i her seferinde yerelde üretilir.
