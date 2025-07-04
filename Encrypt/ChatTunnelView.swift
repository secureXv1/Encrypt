import SwiftUI

struct ChatTunnelView: View {
    let tunnelId: Int
    let alias: String
    @State private var mensaje = ""
    @State private var mensajes: [String] = ["📡 Conectado al túnel"]

    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(mensajes, id: \.self) { msg in
                        Text(msg)
                            .padding(8)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }

            HStack {
                TextField("Escribe un mensaje", text: $mensaje)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Enviar") {
                    enviarMensaje()
                }
            }
            .padding()
        }
        .navigationTitle("Chat \(tunnelId)")
    }

    func enviarMensaje() {
        if mensaje.trimmingCharacters(in: .whitespaces).isEmpty { return }
        mensajes.append("🧑 \(alias): \(mensaje)")
        mensaje = ""
        // Puedes integrar aquí la lógica de envío real
    }
}

