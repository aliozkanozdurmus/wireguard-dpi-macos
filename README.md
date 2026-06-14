# SplitWire Turkey macOS

SplitWire Turkey macOS, macOS üzerinde Discord ve benzeri erişim sorunu yaşanan servisler için iki farklı yöntemi tek uygulamadan yönetir:

- **WireGuard / Cloudflare WARP:** Önerilen yöntem. Sistem seviyesinde çalışır, yeniden başlatmadan sonra otomatik açılır ve SplitWire uygulamasının açık kalmasına gerek kalmaz.
- **ByeDPI:** Yedek yöntem. Yerelde `127.0.0.1:1080` SOCKS5 proxy açar. Kullanıldığı süre boyunca SplitWire uygulaması açık kalmalıdır.

Bu repo artık yeni bir Mac kurulurken baştan sorun çözme süreci yaşamamak için hazır `.app`, kurulum komutları, doğrulama adımları ve sorun giderme notlarıyla birlikte tutuluyor.

## Hangi Yöntem Kullanılmalı?

Gündelik kullanım için **WireGuard** kullan.

WireGuard kurulumu bir kez yapıldıktan sonra:

- Discord normal şekilde açılır.
- SplitWire uygulamasını kapatabilirsin.
- Mac yeniden başlayınca servis otomatik yüklenir.
- Başka sitelerdeki erişim sorunlarında da aynı tünel devrede kalır.

ByeDPI sadece WireGuard istemediğin, geçici test yapmak istediğin veya belli bir uygulamayı SOCKS5 proxy ile başlatman gereken durumlarda kullanılmalı.

> Not: Mevcut `wgcf` profili macOS'ta sistem seviyesinde WireGuard rotası kurar. Uygulamadaki uygulama/tarayıcı listesi kurulum notu olarak config'e yazılır; gerçek anlamda per-app split tunnel değildir.

## Uyumluluk

- macOS 13 Ventura veya üzeri
- Apple Silicon Mac için doğrulandı
- Repo içindeki hazır `SplitWire-Turkey.app` arm64 olarak paketlenmiştir
- Intel Mac hedeflenecekse uygulama ve `ciadpi` binary'si o mimariye göre yeniden hazırlanmalıdır

## Yeni Mac Kurulumu

Yeni bir Apple Silicon Mac'te en kısa yol şu:

```bash
# 1. Gerekli araçlar
brew install bash wireguard-tools wireguard-go

# 2. Repoyu indir
git clone https://github.com/aliozkanozdurmus/SplitWire-Turkey-macOS.git
cd SplitWire-Turkey-macOS

# 3. Hazır uygulamayı Applications'a koy
ditto "SplitWire-Turkey.app" "/Applications/SplitWire-Turkey.app"

# 4. macOS quarantine bilgisini temizle
xattr -rd com.apple.quarantine "/Applications/SplitWire-Turkey.app"

# 5. Uygulamayı aç
open "/Applications/SplitWire-Turkey.app"
```

Homebrew yoksa önce Homebrew kur:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Command Line Tools yoksa macOS şu komutla kurulum penceresi açar:

```bash
xcode-select --install
```

## WireGuard Kurulumu

Uygulama açıldıktan sonra:

1. **WireGuard** sekmesine geç.
2. İstersen **Tarayıcılar için de tünelleme yap** seçeneğini aç.
3. **Standart Kurulum Yap** butonuna bas.
4. macOS admin şifresini gir.
5. Durumun **Aktif** ve tünelin **Çalışıyor** göründüğünü kontrol et.

Bu işlem sırasında uygulama:

- Mac mimarisine uygun son `wgcf` binary'sini indirir.
- Cloudflare WARP profili oluşturur.
- Config'i `/etc/wireguard/wgcf.conf` altına kopyalar.
- `com.splitwire.wireguard` LaunchDaemon dosyasını kurar.
- `wg-quick` için Homebrew Bash ve `wireguard-go` kullanır.

Kurulum bittikten sonra SplitWire uygulamasını kapatabilirsin. WireGuard sistem servisi olarak çalışmaya devam eder.

## Kurulumu Doğrulama

Terminal'de şu kontrolleri çalıştır:

```bash
launchctl print system/com.splitwire.wireguard | sed -n '1,40p'
route -n get discord.com | sed -n '1,12p'
curl -L https://www.cloudflare.com/cdn-cgi/trace | grep warp=
curl -I https://discord.com/api/v10/gateway
```

Beklenen sonuç:

- `launchctl` çıktısında `state = running`
- Route çıktısında `interface: utun...`
- Cloudflare trace çıktısında `warp=on`
- Discord gateway isteğinde `HTTP/2 200` veya `HTTP/1.1 200`

## Günlük Kullanım

WireGuard **Aktif** görünüyorsa normal kullanımda hiçbir şey yapmana gerek yok.

- SplitWire uygulaması açık kalmak zorunda değil.
- Discord'u normal uygulama gibi açabilirsin.
- Mac yeniden başladığında servis otomatik yüklenir.
- Bir sorun olursa SplitWire'ı açıp WireGuard sekmesinden **Kurulumu Onar / Yeniden Başlat** butonuna bas.

WireGuard tüm sistem rotasını etkileyebildiği için ping veya hız internet sağlayıcına, Cloudflare rotasına ve bulunduğun ağa göre değişebilir. Sorun yaşarsan önce uygulamadaki onarım butonunu dene; gerekirse WireGuard'ı kaldırıp tekrar kur.

## ByeDPI Yedek Modu

ByeDPI, WireGuard'dan farklı olarak yerel proxy mantığıyla çalışır.

Kullanım:

1. **ByeDPI** sekmesine geç.
2. Bir preset seç. Genelde önce `Disorder` veya `Split + Disorder` denenebilir.
3. **Başlat** butonuna bas.
4. Discord için hızlı işlemdeki Discord butonunu kullan veya şu komutla başlat:

```bash
open -na "/Applications/Discord.app" --args --proxy-server=socks5://127.0.0.1:1080 --disable-quic
```

ByeDPI için önemli farklar:

- SplitWire uygulaması açık kalmalıdır.
- Proxy adresi `127.0.0.1:1080` olur.
- Port takılırsa **Tümünü Kapat** butonu veya aşağıdaki komut kullanılabilir:

```bash
sudo lsof -ti:1080 | xargs kill -9
```

## Kaynaktan Derleme

Hazır `.app` yeterli değilse veya kod değiştirildiyse:

```bash
swift build -c release
./build.sh
ditto "SplitWire-Turkey.app" "/Applications/SplitWire-Turkey.app"
xattr -rd com.apple.quarantine "/Applications/SplitWire-Turkey.app"
open "/Applications/SplitWire-Turkey.app"
```

Derleme gereksinimleri:

- Swift 5.9+
- macOS 13+
- `bash`, `wireguard-tools`, `wireguard-go`

## Sorun Giderme

### Uygulama açılmıyor

Quarantine bilgisini temizle:

```bash
xattr -rd com.apple.quarantine "/Applications/SplitWire-Turkey.app"
open "/Applications/SplitWire-Turkey.app"
```

Gerekirse Sistem Ayarları > Gizlilik ve Güvenlik ekranından uygulamayı açmaya izin ver.

### WireGuard "Kurulu ama çalışmıyor" görünüyor

Önce uygulamadan **Kurulumu Onar / Yeniden Başlat** butonuna bas.

Hâlâ çalışmazsa servisi temizleyip tekrar uygulamadan onar:

```bash
sudo launchctl bootout system /Library/LaunchDaemons/com.splitwire.wireguard.plist 2>/dev/null || true
sudo /opt/homebrew/bin/bash /opt/homebrew/bin/wg-quick down wgcf 2>/dev/null || true
open "/Applications/SplitWire-Turkey.app"
```

Sonra WireGuard sekmesinden **Kurulumu Onar / Yeniden Başlat** çalıştır.

### `wg`, `wg-quick` veya `wireguard-go` bulunamadı hatası

Homebrew paketlerini tekrar kur:

```bash
brew install bash wireguard-tools wireguard-go
```

Bu projede LaunchDaemon özellikle Homebrew Bash kullanır. macOS'un `/bin/bash` sürümü eski olduğu için `wg-quick` sorun çıkarabilir.

### `wgcf` bozuk veya yanlış mimari indirildi

Uygulama normalde doğru mimariyi otomatik indirir. Yine de sorun yaşarsan:

```bash
rm -f "$HOME/.local/bin/wgcf"
open "/Applications/SplitWire-Turkey.app"
```

Sonra WireGuard kurulumunu tekrar çalıştır.

### Discord açılıyor ama bağlanmıyor

WireGuard aktifken Discord'u tamamen kapatıp yeniden aç:

```bash
pkill Discord 2>/dev/null || true
open -a Discord
```

Ardından doğrulama komutlarındaki `warp=on` ve Discord gateway `200` kontrolünü tekrar yap.

## WireGuard'ı Kaldırma

En temiz yol uygulamadan:

1. SplitWire'ı aç.
2. WireGuard sekmesine geç.
3. **WireGuard'ı Kaldır** butonuna bas.

Manuel temizlik gerekirse:

```bash
sudo /opt/homebrew/bin/bash /opt/homebrew/bin/wg-quick down wgcf 2>/dev/null || true
sudo launchctl bootout system /Library/LaunchDaemons/com.splitwire.wireguard.plist 2>/dev/null || true
sudo rm -f /Library/LaunchDaemons/com.splitwire.wireguard.plist /etc/wireguard/wgcf.conf
rm -f "$HOME/.config/wireguard/wgcf.conf" \
      "$HOME/.config/wireguard/wgcf-account.toml" \
      "$HOME/.config/wireguard/wgcf-profile.conf"
```

## Repo Yapısı

- `SplitWire-Turkey.app`: Yeni Mac'e direkt kopyalanabilecek hazır app bundle.
- `Sources/SplitWireTurkey/Services/WireGuardService.swift`: WireGuard, wgcf, LaunchDaemon ve kaldırma akışı.
- `Sources/SplitWireTurkey/Services/ByeDPIService.swift`: ByeDPI proxy akışı ve favori uygulama başlatma.
- `Sources/SplitWireTurkey/Services/RuntimeSupport.swift`: Homebrew PATH, shell yardımcıları ve `ciadpi` bulma mantığı.
- `Sources/SplitWireTurkey/Views`: SwiftUI ekranları.
- `build.sh`: Swift release build alıp `.app` bundle oluşturan script.

## Notlar

- Bu uygulama resmi Cloudflare, WireGuard veya Discord uygulaması değildir.
- `wgcf register --accept-tos` ile Cloudflare WARP profili oluşturulur.
- Ağ ayarlarını değiştirdiği için WireGuard kurulumu ve kaldırma adımları admin şifresi ister.
- Yeni Mac'te tekrar uğraşmak istemiyorsan bu README'deki "Yeni Mac Kurulumu" ve "Kurulumu Doğrulama" bölümleri yeterli olmalıdır.
