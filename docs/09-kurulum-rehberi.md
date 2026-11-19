# 09 — Kurulum Rehberi (A'dan Z'ye, adım adım)

Bu rehber bilgisayar bilgisi az olan biri için yazıldı. Her adımı **sırayla** yap, atlama.
Komutlar siyah pencereye (**Komut İstemi / PowerShell**) yazılır. `>` işareti komutun parçası değildir.

> **Önemli dürüstlük notu:** Kod yazıldı ama bu kodun **hiçbiri henüz derlenip çalıştırılmadı** (yazıldığı ortamda Flutter/Node derleyicisi yoktu).
> Bu yüzden ilk çalıştırmada küçük hatalar çıkması NORMALDİR. Hata çıkarsa ekran görüntüsünü/yazısını ajana (Claude) yapıştır, düzeltir. Bölüm 12'ye bak.

## İçindekiler
1. Ne kuruyoruz? (kısaca)
2. Bilgisayara kurulacak programlar
3. Projeyi indir (GitHub)
4. Yol A — ÖNCE EMÜLATÖRDE DENE (para/veri riski sıfır)
5. Windows uygulamasını emülatörle çalıştır
6. Android uygulamasını emülatörle çalıştır
7. Yol B — GERÇEK Firebase projesi kur (canlıya geçiş)
8. İlk yönetici kullanıcıyı oluştur
9. Windows kurulum dosyası (.exe) üret
10. Android APK üret ve telefona kur
11. Yedek al ve geri yükle
12. Sorun çıkarsa
13. İlk kullanım sırası (hangi veriyi ne zaman gir)
14. Güvenlik, kota ve günlük kullanım notları

---

## 1) Ne kuruyoruz?
- **Windows uygulaması** (`apps/windows`): bilgisayarda açılan masaüstü program.
- **Android uygulaması** (`apps/android`): telefonda açılan uygulama.
- İkisi de aynı **Firebase** veritabanını kullanır (bedava "Spark" plan). Böylece telefonda girdiğin fatura bilgisayarda da görünür.
- **Emülatör** = Firebase'in bilgisayarında çalışan sahte kopyası. Orada istediğin kadar deneme yapabilirsin, gerçek veri bozulmaz.

## 2) Bilgisayara kurulacak programlar
Hepsini bir kere kur. Kurulumlarda hep **"Next / İleri"** diyebilirsin.

| # | Program | Ne için | İndirme |
|---|---|---|---|
| 1 | **Git** | Projeyi indirmek | https://git-scm.com/download/win |
| 2 | **Node.js (LTS, 20 veya üstü)** | Windows uygulaması + Firebase araçları | https://nodejs.org |
| 3 | **Java (JDK 17+)** | Firebase emülatörü Java ister | https://adoptium.net (Temurin 17 veya 21) |
| 4 | **Flutter SDK (3.22+)** | Android uygulaması | https://docs.flutter.dev/get-started/install/windows |
| 5 | **Android Studio** | Android emülatörü + Android SDK | https://developer.android.com/studio |
| 6 | **Rust** | Windows uygulaması (Tauri) | https://rustup.rs → `rustup-init.exe` |
| 7 | **Visual Studio Build Tools** | Rust'ın derleyicisi | https://visualstudio.microsoft.com/visual-cpp-build-tools/ → "**Desktop development with C++**" kutusunu işaretle |
| 8 | **WebView2** | Windows 10/11'de genelde zaten vardır | https://developer.microsoft.com/microsoft-edge/webview2 |

**Kurulum sonrası kontrol.** Yeni bir Komut İstemi aç (eskisini kapat!) ve sırayla yaz:
```
> git --version
> node --version
> java -version
> flutter --version
> rustc --version
```
Hepsi bir sürüm numarası yazmalı. "tanınmıyor" derse o program kurulmamış ya da bilgisayar yeniden başlatılmalı.

**Flutter için ek:** Android Studio'yu aç → `More Actions → SDK Manager` → "Android SDK" kurulu olsun. Sonra:
```
> flutter doctor --android-licenses
```
Sorulara hep `y` yaz. Ardından `flutter doctor` çalıştır; Android ve Flutter satırlarında ✓ görmelisin (Chrome/Visual Studio satırları kırmızı olsa da sorun değil).

**Firebase aracı (bir kez):**
```
> npm install -g firebase-tools
> firebase --version
```

## 3) Projeyi indir
Komut İstemi'nde proje klasörünü koymak istediğin yere git (örnek: Belgelerim) ve indir:
```
> cd %USERPROFILE%\Documents
> git clone https://github.com/sonarmehmet/sonar-finance.git
> cd sonar-finance
> git checkout main
```
Artık `Documents\sonar-finance` klasörün var. Bundan sonraki tüm komutlar bu klasörün içindedir.

> En güncel kodu almak için ileride: `git pull`.

## 4) Yol A — Önce emülatörde dene
Bu yol bilgisayarında sahte bir Firebase açar. **Para/veri riski yok.**

### 4.1 Emülatörü başlat (pencere AÇIK kalmalı)
```
> scripts\run_emulator.bat
```
Bir sürü yazı akar; sonunda "All emulators ready" görürsün. Bu pencereyi **kapatma**. Tarayıcıdan http://127.0.0.1:4000 açarsan emülatör panelini görürsün.

### 4.2 Örnek (demo) veriyi yükle
**Yeni** bir Komut İstemi aç (ilki açık kalsın):
```
> cd %USERPROFILE%\Documents\sonar-finance
> scripts\seed_emulator.bat
```
"tamam"/bitti benzeri yazı çıkar. Bu komut örnek şirket, cari, ürün, depo ve iki kullanıcı ekler:

| Kullanıcı | E-posta | Şifre | Yetki |
|---|---|---|---|
| Yönetici | `admin@sonar.local` | `Test1234!` | Her şey |
| Çalışan | `calisan@sonar.local` | `Test1234!` | Kısıtlı |

> Emülatörü kapatıp açınca veriler silinir; `seed_emulator.bat`'ı yeniden çalıştırırsın.

## 5) Windows uygulamasını emülatörle çalıştır
1. `apps\windows` klasöründe `.env.example` dosyasını **kopyala**, adını `.env` yap. İçindeki `VITE_USE_EMULATOR=false` satırını `VITE_USE_EMULATOR=true` yap, kaydet. (Diğer satırlar boş kalabilir.)
2. Komut İstemi:
```
> cd %USERPROFILE%\Documents\sonar-finance
> scripts\run_windows.bat
```
3. İlk seferde **10–20 dakika** sürebilir (Rust her şeyi derler). Sonunda bir pencere açılır.
4. Giriş: `admin@sonar.local` / `Test1234!`.

**Derleme öncesi kontrol (önerilir, 1-2 dk):**
```
> cd apps\windows
> npm install
> npm run typecheck
> npm test
```
`typecheck` hata verirse yazıyı ajana yapıştır. `npm test` "pass 51" benzeri bir sonuç vermeli (fatura hesabı vektörleri).

Tarayıcıda hızlı bakmak istersen (Rust gerekmez): `cd apps\windows` → `npm install` → `npm run dev` → yazılan adresi (genelde http://localhost:5173) tarayıcıda aç.

## 6) Android uygulamasını emülatörle çalıştır
### 6.1 Android sanal telefonu oluştur (bir kez)
Android Studio → `More Actions → Virtual Device Manager → Create Device` → "Pixel 6" → bir Android 14 (API 34) görüntüsünü indir → Finish. Yanındaki ▶ ile telefonu aç, ana ekran gelene kadar bekle.

### 6.2 Android dosyalarını hazırla (bir kez)
```
> cd %USERPROFILE%\Documents\sonar-finance\apps\android
> tool\setup_android.bat
```
Bu script `android` klasörünü üretir, internet iznini ekler, simgeyi koyar ve paketleri indirir. Bitince "Tamam" yazar.

### 6.3 Kontrol (önemli — hataları burada yakalarız)
```
> flutter analyze
> flutter test
```
- `flutter analyze` hata (`error`) gösterirse → ekranı kopyalayıp ajana ver.
- `flutter test` "All tests passed" demeli.

### 6.4 Çalıştır
Emülatör (4.1) hâlâ açık olmalı. Sanal telefon açıkken:
```
> flutter run --dart-define=USE_EMULATOR=true
```
Giriş: `admin@sonar.local` / `Test1234!`.

**Gerçek telefonla emülatöre bağlanmak** istersen telefon ve bilgisayar aynı Wi-Fi'de olsun, bilgisayarın IP'sini (`ipconfig` → IPv4) öğren:
```
> flutter run --dart-define=USE_EMULATOR=true --dart-define=EMULATOR_HOST=192.168.1.25
```
(IP'yi kendininkiyle değiştir. Windows Güvenlik Duvarı sorarsa izin ver.)

## 7) Yol B — Gerçek Firebase projesi (canlıya geçiş)
**Ancak Yol A'da her şey düzgün çalışınca** buraya geç.

### 7.1 Proje oluştur
1. https://console.firebase.google.com → Google hesabınla gir → **Add project / Proje ekle**.
2. Ad: `sonar-finance-xxxx` (benzersiz olmalı; sonunda rakam kullan). Google Analytics'i **kapat**. Oluştur.
3. Proje **kimliğini** (Project ID) not al (örnek: `sonar-finance-7421`).

### 7.2 Hizmetleri aç
- Sol menü **Build → Authentication → Get started → Sign-in method → Email/Password → Enable → Save**.
- Sol menü **Build → Firestore Database → Create database** → konum: `eur3` (Avrupa) veya size en yakın → **Production mode** → Enable.
- Plan **Spark (ücretsiz)** kalsın; kredi kartı girme.

### 7.3 Kuralları ve dizinleri yükle
```
> cd %USERPROFILE%\Documents\sonar-finance\firebase
> firebase login
```
Tarayıcı açılır, hesabını seç, izin ver. Sonra:
1. `firebase\.firebaserc` dosyasını Not Defteri ile aç, `"default": "sonar-finance-REPLACE-ME"` yazan yeri **kendi proje kimliğinle** değiştir, kaydet.
2. Yükle:
```
> firebase deploy --only firestore:rules,firestore:indexes
```
"Deploy complete!" yazmalı. (Dizinlerin oluşması birkaç dakika sürer.)

### 7.4 Uygulamaları kaydet ve ayar değerlerini al
Firebase konsolunda ⚙ **Project settings → General → Your apps**:
- **Web app (</>)** ekle → ad: `windows` → Register. Çıkan `firebaseConfig` içinden `apiKey`, `authDomain`, `projectId`, `appId` değerlerini kopyala.
- Windows için: `apps\windows\.env` dosyasını doldur:
```
VITE_FIREBASE_API_KEY=...apiKey...
VITE_FIREBASE_AUTH_DOMAIN=...authDomain...
VITE_FIREBASE_PROJECT_ID=...projectId...
VITE_FIREBASE_APP_ID=...appId...
VITE_USE_EMULATOR=false
```
- **Android** için: Project settings → "Add app" → Android → paket adı `com.sonar.sonar_finance` → Register (diğer adımları geç). Sonra:
```
> dart pub global activate flutterfire_cli
> cd %USERPROFILE%\Documents\sonar-finance\apps\android
> flutterfire configure --project=SENIN-PROJE-KIMLIGIN --platforms=android
```
Bu, `lib\core\firebase\firebase_options.dart` dosyasını gerçek değerlerle **yeniden yazar**. (Bu dosyanın yeni halini git'e eklemek istersen sorun yok; bu değerler gizli anahtar değildir.)

## 8) İlk yönetici kullanıcıyı oluştur
Uygulama giriş için hem bir Auth kullanıcısı hem de bir `users/{uid}` belgesi ister. İlk yönetici için elle yapılır (bir kez):

1. Firebase konsolu → **Authentication → Users → Add user** → e-posta ve şifre yaz → Add. Oluşan kullanıcının **User UID** değerini kopyala.
2. **Firestore Database → Start collection**:
   - Koleksiyon kimliği: `companies` → Belge kimliği: `sonar` → alanlar:
     - `companyId` (string) = `sonar`
     - `name` (string) = şirket adın
     - `currency` (string) = `TRY`
     - `schemaVersion` (number) = `1`
     - `settings` (map): `allowNegativeStock` (boolean) = `false`, `defaultVatBp` (number) = `2000`, `invoicePrefix` (map): `sales`=`SF`, `purchase`=`AF`, `sales_return`=`SI`, `purchase_return`=`AI`
   - Yeni koleksiyon `users` → Belge kimliği: **kopyaladığın UID** → alanlar:
     - `companyId` (string) = `sonar`
     - `displayName` (string) = adın
     - `email` (string) = e-postan
     - `role` (string) = `admin`
     - `permissions` (map) = boş
     - `active` (boolean) = `true`
3. Uygulamayı aç, bu e-posta/şifre ile gir. Diğer kullanıcıları artık **Windows uygulamasında soldaki Kullanıcı Yönetimi** ekranından eklersin (ad, e-posta, şifre, rol ve yetkiler; yönetici oturumu kapanmaz).

> İpucu: Hangi alanların tam olarak gerektiğini görmek için `firebase\seed\seed.js` dosyasındaki `companies/sonar` ve `users/` örneğine bak.

## 9) Windows kurulum dosyası (.exe) üret
`apps\windows\.env` (7.4'teki gerçek değerlerle, `VITE_USE_EMULATOR=false`) hazır olmalı:
```
> scripts\build_windows.bat
```
Bittiğinde `build\windows\SONAR-FINANCE-Setup.exe` oluşur. Bunu çift tıklayıp kur; masaüstünde/Başlat menüsünde program görünür. Başka bilgisayara kurmak için sadece bu `.exe` yeter.

## 10) Android APK üret ve telefona kur
```
> scripts\build_android.bat
```
Çıktı: `build\android\app-release.apk`. Telefona aktar (USB, Drive, WhatsApp "belge") → dosyaya dokun → "Bilinmeyen kaynaklardan kuruluma izin ver" → Kur.
> Not: Bu APK **debug anahtarıyla** imzalanır, kişisel kullanım için yeterlidir. Play Store için ayrı imza anahtarı gerekir (şimdilik gerekmiyor).

## 11) Yedek al ve geri yükle
- **Yedek al (önerilen: haftada bir + büyük işlemden önce):** Windows uygulaması → **Ayarlar → Yedekleme → Yedek Al**. Çıkan `sonar-backup-....json` dosyasını **bilgisayar dışında** (Drive / harici disk) da sakla.
- **Geri yükleme** uygulamadan yapılmaz (tehlikeli). Gerekirse: `firebase\tools\restore.js` — ayrıntı `docs\06-yedekleme-geri-yukleme.md`.
- **Tutarlılık kontrolü:** `firebase\tools\recalc.js` bakiyeleri yeniden hesaplayıp farkı gösterir.

## 12) Sorun çıkarsa
| Belirti | Çözüm |
|---|---|
| `... is not recognized` | Program kurulu değil veya PATH için bilgisayarı yeniden başlat; yeni Komut İstemi aç |
| Emülatör "Java" hatası | JDK 17+ kur (Bölüm 2/3), yeni pencere aç |
| `flutter analyze` hata veriyor | **Beklenen** (kod ilk kez derleniyor). Çıktıyı ajana yapıştır |
| `npm run build` / `tauri` hata | Rust + Visual Studio Build Tools (C++) kurulu mu? Çıktıyı ajana yapıştır |
| Giriş yapılamıyor | Emülatör açık mı? `seed_emulator.bat` çalıştı mı? Windows'ta `.env` içinde `VITE_USE_EMULATOR=true` mı? |
| Android'de bağlanamıyor | `--dart-define=USE_EMULATOR=true` yazdın mı? Gerçek telefonda `EMULATOR_HOST` verdin mi? |
| "permission-denied" | Kurallar yüklenmemiş (7.3) veya `users/{uid}` belgesi yok/yanlış (8) |
| Liste boş geliyor | Dizinler oluşuyor olabilir (birkaç dakika bekle) veya seed çalışmadı |
| Telefonda "çevrimdışı" şeridi | İnternet yok; yazılanlar kuyruğa alınır, bağlanınca gönderilir (Ayarlar/Profil → Senkronizasyon) |

**Ajana hata nasıl iletilir?** Siyah penceredeki hata yazısının **tamamını** (ilk kırmızı satırdan itibaren) kopyala, hangi komutu çalıştırdığını yaz. Ekran görüntüsü de olur.


## 13) İlk kullanım sırası (gerçek veriyle başlarken)
Sırayı bozma; çünkü her adım bir sonrakinin ihtiyacıdır.
1. **Ayarlar → Şirket ve Fatura:** şirket adı, vergi bilgileri, fatura ön ekleri (SF/AF/SI/AI), varsayılan KDV. "Negatif stoğa izin ver" kapalı kalsın (stok eksiye düşemez).
2. **Kasa ve Banka → Yeni Kasa / Yeni Banka Hesabı:** hesapları aç; **Açılış Bakiyesi** kutusuna bugünkü gerçek bakiyeyi yaz (bu bir kez yapılır, sonra değiştirilemez; düzeltme için hesaplar arası transfer/gider/tahsilat kullanılır).
3. **Stok Yönetimi → Depolar:** en az bir depo (biri "varsayılan").
4. **Stok Yönetimi → Ürünler:** ürünleri gir (KDV oranı, birim, "stok takibi yap"). Mevcut stok için **Stok Girişi** işlemini kullan (miktar + birim maliyet): ortalama maliyet buradan oluşur.
5. **Cari Hesaplar:** müşteri/tedarikçileri ekle. Eski borç/alacak bakiyesi taşıyorsan her cari için bir **açılış faturası** (veya tahsilat/ödeme) girerek başla; bakiye alanı elle yazılamaz (bilerek böyle tasarlandı).
6. **Projeler:** sözleşme bedeli (KDV hariç) ve disiplin bütçeleri.
7. **Faturalar → Yeni Fatura:** önce **Taslak Kaydet**, kontrol et, sonra **Faturayı Kaydet** (keser: stok ve cari bakiye değişir). Kesilen fatura düzenlenmez; hata varsa **İptal Et** (ters kayıt) ve yenisini gir.
8. **Tahsilat/Ödeme:** cari sayfasından veya Kasa ve Banka'dan; faturalara otomatik (en eski vadeden) ya da elle dağıt.
9. **Gelir ve Gider:** masrafları (varsa proje + disiplin ile) gir; KDV dahil tutar yazılır.
10. **Genel Bakış ve Raporlar:** rakamlar `stats/summary` belgesinden okunur. Şüphe olursa Ayarlar → Tutarlılık Denetimi (yönetici) çalıştır; fark çıkarsa `firebase\tools\recalc.js --fix` (docs/06).

## 14) Güvenlik, kota ve günlük kullanım notları
- **Firebase `apiKey` gizli değildir**; asıl koruma `firestore.rules` ve giriş yapmış kullanıcıdır. Kuralları yüklemeden (7.3) canlıya **geçme**. Kimseye yönetici rolü verme; çalışanlara yalnız gereken yetkileri işaretle.
- **Kayıt silinmez:** finansal belge iptal edilir (ters kayıt oluşur). Bu, muhasebe izi için bilerek böyledir.
- **Çevrimdışı:** internet yokken yalnız taslak fatura, cari, ürün, depo kaydedilir. Fatura kesme, tahsilat/ödeme, gider, transfer, stok işlemi ve iptaller **bağlantı ister**.
- **Spark (ücretsiz) kotaları:** günde yaklaşık 50.000 okuma / 20.000 yazma. Tek şirket günlük kullanım için yeterli; Yedek Al ve Tutarlılık Denetimi tüm belgeleri okur, günde birkaç kezden fazla çalıştırma.
- **Bir faturada çok kalem:** `firestore.rules` bir işlemde en fazla 20 farklı belgeye bakabilir; farklı stok seviyesi (ürün+depo) sayısı yaklaşık 15'i aşan tek fatura reddedilebilir. Böyle büyük faturaları ikiye böl (bu sınır docs/10 P0-4'te test edilecek).
- **Güncelleme:** `git pull` → Windows için `scripts\build_windows.bat`, Android için `scripts\build_android.bat` → yeni dosyayı tekrar kur. Veriler Firebase'de olduğu için kaybolmaz. Kurallar/dizinler değiştiyse ayrıca `firebase deploy --only firestore:rules,firestore:indexes`.
- **Yedek:** haftada bir + toplu iş öncesi (Bölüm 11). Yedeği bilgisayar dışına kopyala.
- **Şifre unutulursa:** Firebase konsolu → Authentication → kullanıcının yanındaki ⋮ → Reset password.
