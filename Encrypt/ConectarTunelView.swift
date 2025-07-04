import SwiftUI

struct ConectarTunelView: View {
    @State private var tunnelName = ""
    @State private var alias = ""
    @State private var password = ""
    @State private var mensaje = ""
    @Environment(\.presentationMode) var presentationMode
    @State private var navegar = false
    @State private var tunnelId: Int?

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                TextField("Nombre del túnel", text: $tunnelName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                TextField("Alias", text: $alias)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                SecureField("Contraseña del túnel", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button("Conectar") {
                    obtenerIDyConectar()
                }

                Text(mensaje)
                    .foregroundColor(.green)

                // Navegación automática al chat
                NavigationLink(
                    destination: ChatTunnelView(tunnelId: tunnelId ?? 0, alias: alias),
                    isActive: $navegar,
                    label: { EmptyView() }
                )
            }
            .padding()
            .navigationTitle("Conectarse a Túnel")
        }
    }

    func obtenerIDyConectar() {
        guard !tunnelName.isEmpty, !alias.isEmpty, !password.isEmpty else {
            mensaje = "⚠️ Completa todos los campos"
            return
        }

        guard let url = URL(string: "http://symbolsaps.ddns.net:8000/api/tunnels/get?name=\(tunnelName)") else { return }

        URLSession.shared.dataTask(with: url) { data, response, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = json["id"] as? Int else {
                DispatchQueue.main.async {
                    mensaje = "❌ Túnel no encontrado"
                }
                return
            }

            conectar(tunnelId: id)
        }.resume()
    }

    func conectar(tunnelId: Int) {
        guard let url = URL(string: "http://symbolsaps.ddns.net:8000/api/tunnels/join") else { return }

        let body: [String: Any] = [
            "tunnel_id": tunnelId,
            "password": password,
            "alias": alias
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { _, response, _ in
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                DispatchQueue.main.async {
                    mensaje = "❌ Contraseña incorrecta"
                }
                return
            }

            registrarAlias(tunnelId: tunnelId)
        }.resume()
    }

    func registrarAlias(tunnelId: Int) {
        guard let url = URL(string: "http://symbolsaps.ddns.net:8000/api/registrar_alias") else { return }

        let uuid = ClientService.shared.getOrCreateUUID()
        let body: [String: Any] = [
            "uuid": uuid,
            "tunnel_id": tunnelId,
            "alias": alias
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { _, response, _ in
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                DispatchQueue.main.async {
                    mensaje = "⚠️ Error registrando alias"
                }
                return
            }

            DispatchQueue.main.async {
                self.tunnelId = tunnelId
                self.navegar = true
            }
        }.resume()
    }
}
