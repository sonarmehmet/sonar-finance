# 03 — Güvenlik Kuralları

Dosya: `firebase/firestore.rules`.

## İlk kurulum (bir kez, konsoldan)
1. Firebase Console → Authentication → E-posta/Şifre aç, yönetici hesabını ekle (uid'yi not al).
2. Firestore'da `companies/{cid}` belgesini oluştur (`name`, `currency:'TRY'`, `settings{...}`, `schemaVersion:1`).
3. `users/{uid}` belgesini oluştur: `companyId=cid, role='admin', active=true, permissions={}, displayName, email`.
4. Sonrası uygulamadan (Kullanıcı Yönetimi); yeni kullanıcı için önce Authentication'da hesap açılır, sonra `users/{uid}` yönetici tarafından yazılır.

## Garantiler
- Şirket izolasyonu: yalnız `users/{uid}.companyId == cid` ve `active` olan kullanıcı okur/yazar.
- Rol/izin: `admin` hepsi; `employee` yalnız `permissions` içindeki anahtarlar (`invoice.write, party.write, stock.write, finance.write, project.write`).
- **Bakiye alanları** (`parties.balanceMinor`, `accounts.balanceMinor`, `stock_levels.qtyMilli`) yalnız aynı batch'te `{lastTxId}_{id}` hareket belgesi **ve** farka eşit `delta` ile değişir (`getAfter`). Hareket belgeleri değiştirilemez/silinemez.
- **Çift gönderim**: `txns/{txId}` yalnız bir kez oluşturulabilir; fatura kesme, ödeme, gider ve iptaller yeni bir `txns` ile birlikte yazılmak zorundadır.
- Kesilmiş fatura: yalnız `status, cancelTxId, paidMinor, paymentStatus, lastTxId, updatedAt` değişebilir. Taslak dışında silme yok. İptal edilmiş fatura değişmez.
- `audit_logs`: yalnız `create`; okuma yalnız yönetici.

## Bilinen sınırlar (kabul edilen)
- Kurallar toplam/KDV doğruluğunu ve hareketlerin ürün/hesapla iç tutarlılığını **hesaplamaz**; istemci doğru yazmak zorundadır. Tutarsızlık için "yeniden hesapla" aracı (F5).
- Yetkili kullanıcı kuralları aşamaz, ancak kendi yetkisi içinde yanlış tutar yazabilir (özel, tek şirket kullanımı için kabul).
- Kurallar emülatörde test edilene kadar (F7) "doğrulanmış" sayılmaz.
