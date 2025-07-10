import SwiftUI

struct Tunnel: Identifiable, Decodable {
    let id: Int
    let name: String
    let fecha: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case fecha = "created_at"
    }
}

struct TunnelDisplay: Identifiable {
    let id: Int
    let name: String
    let fecha: Date
    let esReciente: Bool

    var icono: String {
        esReciente ? "clock.arrow.circlepath" : "shield.lefthalf.fill"
    }

    var color: Color {
        esReciente ? .green : .blue
    }

    var labelFecha: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let fechaStr = formatter.string(from: fecha)
        return esReciente ? "Última conexión \(fechaStr)" : "Creado en \(fechaStr)"
    }
}

struct TunnelPanelView: View {
    @State private var misTuneles: [TunnelDisplay] = []
    @State private var recientes: [TunnelDisplay] = []
    @State private var selectedTunnel: TunnelDisplay? = nil
    @State private var showPasswordPrompt = false
    @State private var alias = ""
    @State private var password = ""
    @State private var navigateToChat = false
    @State private var tunnelId: Int? = nil
    @State private var showCrear = false
    @State private var showConectar = false
    @State private var modo = 0

    let uuid = ClientService.shared.getOrCreateUUID()

    var body: some View {
        VStack {
            // Encabezado y botón +
            HStack {
                Text("Túneles")
                    .font(.title2).bold()
                Spacer()
                Menu {
                    Button("Crear Túnel") { showCrear = true }
                    Button("Conectar Manualmente") { showConectar = true }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)

            // Selector
            Picker("Modo", selection: $modo) {
                Text("Mis túneles").tag(0)
                Text("Recientes").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            // Lista personalizada
            ScrollView {
                LazyVStack(spacing: 0) { // ⬅️ Sin espacio entre tarjetas
                    let tuneles = modo == 0 ? misTuneles : recientes
                    ForEach(tuneles) { tunel in
                        SwipeableTunnelCard(tunnel: tunel,
                                            onTap: {
                                                selectedTunnel = tunel
                                                showPasswordPrompt = true
                                            },
                                            onDelete: { eliminarTunnel(tunel) },
                                            onEdit: { editarPassword(tunel) })
                            .padding(.horizontal, 12) // ⬅️ Bordes suaves laterales
                    }
                }
                .padding(.top, 8)
            }
            .onAppear(perform: cargarTuneles)
        }
        .sheet(isPresented: $showPasswordPrompt) {
            if let tunel = selectedTunnel {
                PasswordPromptView(tunnel: tunel, onJoin: { pass, aliasInput in
                    self.password = pass
                    self.alias = aliasInput
                    self.joinTunnel(tunnelId: tunel.id)
                })
            }
        }
        .sheet(isPresented: $showCrear) {
            CrearTunelView()
        }
        .sheet(isPresented: $showConectar) {
            ConectarTunelView()
        }
        .background(
            NavigationLink(destination: ChatTunnelView(tunnelId: tunnelId ?? 0, alias: alias), isActive: $navigateToChat) {
                EmptyView()
            }
        )
    }
    func eliminarTunnel(_ tunnel: TunnelDisplay) {
        print("🗑 Eliminar túnel: \(tunnel.name)")
        // Aquí puedes agregar llamada al backend y actualizar la lista
    }

    func editarPassword(_ tunnel: TunnelDisplay) {
        print("🔐 Editar contraseña de: \(tunnel.name)")
        // Aquí puedes mostrar un sheet o alert para editar la contraseña
    }

    func cargarTuneles() {
        guard let url = URL(string: "http://symbolsaps.ddns.net:8000/api/tuneles/\(uuid)") else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let mis = json["mis_tuneles"] as? [[String: Any]],
                  let rec = json["conexiones_recientes"] as? [[String: Any]] else { return }

            DispatchQueue.main.async {
                self.misTuneles = mis.compactMap {
                    guard let id = $0["id"] as? Int,
                          let name = $0["name"] as? String,
                          let millis = $0["created_at"] as? Double
                    else {
                        print("❌ Error parseando túnel propio: \($0)")
                        return nil
                    }
                    let fecha = Date(timeIntervalSince1970: millis / 1000)
                    return TunnelDisplay(id: id, name: name, fecha: fecha, esReciente: false)
                }

                self.recientes = rec.compactMap {
                    guard let id = $0["id"] as? Int,
                          let name = $0["name"] as? String,
                          let millis = $0["ultima_conexion"] as? Double
                    else {
                        print("❌ Error parseando túnel reciente: \($0)")
                        return nil
                    }
                    let fecha = Date(timeIntervalSince1970: millis / 1000)
                    return TunnelDisplay(id: id, name: name, fecha: fecha, esReciente: true)
                }
            }
        }.resume()
    }

    func joinTunnel(tunnelId: Int) {
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
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            registrarAlias(tunnelId: tunnelId)
        }.resume()
    }

    func registrarAlias(tunnelId: Int) {
        guard let url = URL(string: "http://symbolsaps.ddns.net:8000/api/registrar_alias") else { return }

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
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            DispatchQueue.main.async {
                self.tunnelId = tunnelId
                self.navigateToChat = true
            }
        }.resume()
    }
}

struct SwipeableTunnelCard: View {
    let tunnel: TunnelDisplay
    let onTap: () -> Void
    let onDelete: () -> Void
    let onEdit: (() -> Void)? // Solo para "Mis túneles"

    @State private var offset: CGFloat = 0
    @GestureState private var isDragging = false

    var body: some View {
        ZStack {
            // Fondo completo con botones visibles
            HStack(spacing: 0) {
                Spacer()

                if !tunnel.esReciente {
                    Button(action: { onEdit?() }) {
                        ZStack {
                            Color.blue
                            Image(systemName: "key.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 20))
                        }
                    }
                    .frame(width: 60)
                }

                Button(action: onDelete) {
                    ZStack {
                        Color.red
                        Image(systemName: "trash")
                            .foregroundColor(.white)
                            .font(.system(size: 20))
                    }
                }
                .frame(width: 60)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .cornerRadius(10)
            .padding(.horizontal, 12)

            // Tarjeta encima
            TunnelCard(tunnel: tunnel, onTap: onTap)
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .updating($isDragging) { _, state, _ in state = true }
                        .onChanged { gesture in
                            let limit = tunnel.esReciente ? -60.0 : -120.0
                            offset = max(limit, gesture.translation.width)
                        }
                        .onEnded { gesture in
                            let maxOffset = tunnel.esReciente ? -60.0 : -120.0
                            if gesture.translation.width < -40 {
                                offset = maxOffset
                            } else {
                                offset = 0
                            }
                        }
                )
        }
        .background(Color(.systemBackground)) // Fondo para que se note la separación
        .overlay(
            Divider()
                .padding(.leading, 60),
            alignment: .bottom
        )
        .animation(.easeInOut(duration: 0.2), value: offset)
    }
}


struct TunnelCard: View {
    let tunnel: TunnelDisplay
    let onTap: () -> Void

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .cornerRadius(10)

            HStack(spacing: 12) {
                Image(systemName: "shield.lefthalf.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 16))

                VStack(alignment: .leading, spacing: 2) {
                    Text(tunnel.name)
                        .font(.subheadline).bold()
                        .foregroundColor(.primary)
                    Text(tunnel.labelFecha)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: tunnel.esReciente ? "clock.arrow.circlepath" : "lock.fill")
                        .foregroundColor(tunnel.esReciente ? .green : .orange)

                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                    .font(.system(size: 14))
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
        }
        .onTapGesture { onTap() }
    }
}

struct PasswordPromptView: View {
    let tunnel: TunnelDisplay
    var onJoin: (String, String) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var password = ""
    @State private var alias = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Alias")) {
                    TextField("Alias", text: $alias)
                }
                Section(header: Text("Contraseña del túnel")) {
                    SecureField("Contraseña", text: $password)
                }
                Section {
                    Button("Conectar") {
                        presentationMode.wrappedValue.dismiss()
                        onJoin(password, alias)
                    }.disabled(password.isEmpty || alias.isEmpty)
                }
            }
            .navigationTitle("Conectar a \(tunnel.name)")
        }
    }
}
