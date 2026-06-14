# wireguard-dpi-macos Proje Yapısı

Bu repo, macOS için SwiftUI tabanlı bir WireGuard/WARP ve ByeDPI yönetim uygulamasıdır.

## Üst Seviye Dosyalar

```text
wireguard-dpi-macos/
├── Package.swift
├── README.md
├── KULLANIM.md
├── build.sh
├── wireguard-dpi-macos.app/
├── Sources/
│   └── WireGuardDPIMacOS/
│       ├── WireGuardDPIMacOSApp.swift
│       ├── Models/
│       ├── Services/
│       ├── Views/
│       └── Resources/
└── byedpi/
```

## Önemli Modüller

- `Sources/WireGuardDPIMacOS/WireGuardDPIMacOSApp.swift`: SwiftUI uygulama girişi.
- `Sources/WireGuardDPIMacOS/Models/AppState.swift`: Uygulama durumu, favoriler ve WireGuard durum kontrolü.
- `Sources/WireGuardDPIMacOS/Services/WireGuardService.swift`: `wgcf`, WireGuard config üretimi, LaunchDaemon kurulumu ve kaldırma akışı.
- `Sources/WireGuardDPIMacOS/Services/ByeDPIService.swift`: `ciadpi` süreci, SOCKS5 proxy ve favori uygulama başlatma akışı.
- `Sources/WireGuardDPIMacOS/Services/RuntimeSupport.swift`: PATH, shell yardımcıları, LaunchDaemon sabitleri ve `ciadpi` binary bulma mantığı.
- `Sources/WireGuardDPIMacOS/Views/`: SwiftUI ekranları.
- `Sources/WireGuardDPIMacOS/Resources/bin/ciadpi`: Uygulama bundle içine kopyalanan ByeDPI binary'si.

## Paket ve App Adı

- Swift package: `wireguard-dpi-macos`
- Executable: `wireguard-dpi-macos`
- App bundle: `wireguard-dpi-macos.app`
- Bundle identifier: `com.aliozkanozdurmus.wireguard-dpi-macos`
- WireGuard LaunchDaemon: `com.aliozkanozdurmus.wireguard-dpi-macos.wireguard`

Eski kurulumlardan gelen önceki LaunchDaemon label'ı geriye dönük temizlik için kod içinde hâlâ tanınır.

## Derleme

```bash
swift build -c release
./build.sh
```

`build.sh`, release binary'sini alır, `wireguard-dpi-macos.app` bundle'ını oluşturur, `ciadpi` binary'sini bundle içine kopyalar ve app'i ad-hoc imzalar.

## Kurulum

```bash
ditto "wireguard-dpi-macos.app" "/Applications/wireguard-dpi-macos.app"
xattr -rd com.apple.quarantine "/Applications/wireguard-dpi-macos.app"
open "/Applications/wireguard-dpi-macos.app"
```

## Doğrulama

```bash
swift build -c release
./build.sh
codesign --verify --deep --strict "wireguard-dpi-macos.app"
file "wireguard-dpi-macos.app/Contents/MacOS/wireguard-dpi-macos"
```
