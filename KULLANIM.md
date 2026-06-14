# wireguard-dpi-macos Kullanım Kılavuzu

Bu dosya kısa kullanım referansıdır. Yeni Mac kurulumu, doğrulama ve sorun giderme için ana kaynak [README.md](README.md) dosyasıdır.

## Normal Kullanım

Önerilen mod WireGuard'dır.

1. `wireguard-dpi-macos.app` uygulamasını aç.
2. **WireGuard** sekmesine geç.
3. **Standart Kurulum Yap** veya daha önce kurulduysa **Kurulumu Onar / Yeniden Başlat** butonuna bas.
4. macOS admin şifresini gir.
5. Durum **Aktif** göründüğünde uygulamayı kapatabilirsin.

WireGuard sistem servisi olarak çalışır. Uygulamanın açık kalmasına gerek yoktur.

## Discord

WireGuard aktifse Discord'u normal uygulama gibi aç:

```bash
open -a Discord
```

Bağlantıdan emin olmak için:

```bash
curl -I https://discord.com/api/v10/gateway
```

`200` cevabı beklenir.

## ByeDPI Yedek Kullanım

WireGuard yerine geçici SOCKS5 proxy kullanmak istersen:

1. **ByeDPI** sekmesine geç.
2. `Disorder` veya `Split + Disorder` presetlerinden biriyle başlat.
3. Discord'u proxy argümanıyla aç:

```bash
open -na "/Applications/Discord.app" --args --proxy-server=socks5://127.0.0.1:1080 --disable-quic
```

ByeDPI açık kaldığı sürece çalışır. Uygulamayı kapatırsan proxy de kapanır.

## Hızlı Kontroller

```bash
launchctl print system/com.aliozkanozdurmus.wireguard-dpi-macos.wireguard | sed -n '1,40p'
route -n get discord.com | sed -n '1,12p'
curl -L https://www.cloudflare.com/cdn-cgi/trace | grep warp=
```

Beklenen durum:

- `state = running`
- `interface: utun...`
- `warp=on`

## Kaldırma

Uygulama içinden **WireGuard'ı Kaldır** butonunu kullan.

Manuel temizlik gerekirse:

```bash
sudo /opt/homebrew/bin/bash /opt/homebrew/bin/wg-quick down wgcf 2>/dev/null || true
sudo launchctl bootout system/com.aliozkanozdurmus.wireguard-dpi-macos.wireguard 2>/dev/null || true
sudo rm -f /Library/LaunchDaemons/com.aliozkanozdurmus.wireguard-dpi-macos.wireguard.plist
sudo rm -f /etc/wireguard/wgcf.conf
rm -f "$HOME/.config/wireguard/wgcf.conf" \
      "$HOME/.config/wireguard/wgcf-account.toml" \
      "$HOME/.config/wireguard/wgcf-profile.conf"
```
