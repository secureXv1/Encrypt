import SwiftUI

struct CrearTunelView: View {
    @State private var nombre = ""
    @State private var password = ""
    @State private var mensaje = ""
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 20) {
            TextField("Nombre del túnel", text: $nombre)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            SecureField("Contraseña del túnel", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Button("Crear túnel") {
                crearTunel()
            }

            Text(mensaje)
                .foregroundColor(.green)
        }
        .padding()
        .navigationTitle("Crear Túnel")
    }

    func crearTunel() {
        guard let url = URL(string: "http://symbolsaps.ddns.net:8000/api/tunnels/create") else { return }

        let uuid = ClientService.shared.getOrCreateUUID()
        let payload: [String: Any] = [
            "name": nombre,
            "password": password,
            "uuid": uuid
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let id = json["tunnel_id"] as? Int {
                DispatchQueue.main.async {
                    mensaje = "✅ Túnel creado con ID: \(id)"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            } else {
                DispatchQueue.main.async {
                    mensaje = "❌ Error al crear túnel"
                }
            }
        }.resume()
    }
}
