import SwiftUI

@main
struct EndCryptApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill") // Reemplazo de home.svg
                    Text("Inicio")
                }
            EncryptionPanelView()
                .tabItem {
                    Image(systemName: "lock.shield.fill") // Reemplazo de lock.svg
                    Text("Cifrado")
                }
            TunnelPanelView()
                .tabItem {
                    Image(systemName: "antenna.radiowaves.left.and.right") // Reemplazo de satellite.svg
                    Text("Túneles")
                }

            
        }
        .accentColor(Color(hex: "#00BCD4"))
    }
}


extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255

        self.init(red: r, green: g, blue: b)
    }
}
