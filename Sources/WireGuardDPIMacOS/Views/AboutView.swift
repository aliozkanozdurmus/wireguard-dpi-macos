import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App Icon and Version
                VStack(spacing: 12) {
                    Image(systemName: "network.badge.shield.half.filled")
                        .resizable()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.accentColor)

                    Text("wireguard-dpi-macos")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("macOS Edition 1.0")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding()

                Divider()

                // Description
                GroupBox(label: Label("Hakkında", systemImage: "info.circle.fill")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("wireguard-dpi-macos, macOS üzerinde WireGuard ve ByeDPI akışlarını tek yerden yöneten bağımsız bir ağ aracıdır.")
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Ana kullanım senaryosu Discord ve erişim sorunu yaşanan servisler için kalıcı WireGuard/WARP tüneli kurmaktır.")
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                // Features
                GroupBox(label: Label("Özellikler", systemImage: "star.fill")) {
                    VStack(alignment: .leading, spacing: 8) {
                        FeatureRow(icon: "network", text: "WireGuard tabanlı tünelleme")
                        FeatureRow(icon: "shield.checkered", text: "ByeDPI ile DPI aşımı (SOCKS5 proxy)")
                        FeatureRow(icon: "gearshape.2", text: "Kolay DNS yapılandırması")
                        FeatureRow(icon: "folder.badge.plus", text: "Özelleştirilebilir uygulama listesi")
                        FeatureRow(icon: "command", text: "Discord otomatik proxy yapılandırması")
                    }
                    .padding()
                }

                GroupBox(label: Label("Teşekkürler", systemImage: "heart.fill")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Kullanılan Araçlar:")
                            .fontWeight(.semibold)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• wgcf by ViRb3")
                            Text("• WireGuard")
                            Text("• ByeDPI by hufrea")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                }

                // License
                GroupBox(label: Label("Lisans", systemImage: "doc.text.fill")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MIT License")
                            .fontWeight(.semibold)
                        Text("Copyright © 2026 wireguard-dpi-macos contributors")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                // Links
                VStack(spacing: 8) {
                    Button(action: {
                        if let url = URL(string: "https://github.com/aliozkanozdurmus/wireguard-dpi-macos") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "link.circle.fill")
                            Text("GitHub Sayfası")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(.accentColor)
            Text(text)
            Spacer()
        }
    }
}
