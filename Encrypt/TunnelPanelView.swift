import SwiftUI

struct Tunnel: Identifiable, Decodable {
    let id: Int
    let name: String
}

struct TunnelPanelView: View {
    @State private var misTuneles: [Tunnel] = []
    @State private var recientes: [Tunnel] = []
    @State private var selectedTunnel: Tunnel? = nil
    @State private var showPasswordPrompt = false
    @State private var alias = ""
    @State private var password = ""
    @State private var navigateToChat = false
    @State private var tunnelId: Int? = nil
    @State private var showCrear = false
    @State private var showConectar = false
    @State private var modo = 0 // 0 = Mis túneles, 1 = Recientes

    let uuid = ClientService.shared.getOrCreateUUID()

    var body: some View {
        VStack {
            // Encabezado personalizado como en EncryptionPanelView
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

            // Selector tipo pestaña
            Picker("Modo", selection: $modo) {
                Text("Mis túneles").tag(0)
                Text("Recientes").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            // Lista
            List {
                let tuneles = modo == 0 ? misTuneles : recientes

                ForEach(tuneles) { tunel in
                    TunnelCard(tunnel: tunel) {
                        selectedTunnel = tunel
                        showPasswordPrompt = true
                    }
                }
            }
            .listStyle(PlainListStyle())
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

    func cargarTuneles() {
        guard let url = URL(string: "http://symbolsaps.ddns.net:8000/api/tuneles/\(uuid)") else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let mis = json["mis_tuneles"] as? [[String: Any]],
                  let rec = json["conexiones_recientes"] as? [[String: Any]] else { return }

            DispatchQueue.main.async {
                self.misTuneles = mis.compactMap { Tunnel(id: $0["id"] as? Int ?? 0, name: $0["name"] as? String ?? "") }
                self.recientes = rec.compactMap { Tunnel(id: $0["id"] as? Int ?? 0, name: $0["name"] as? String ?? "") }
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

struct TunnelCard: View {
    let tunnel: Tunnel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading) {
                    Text(tunnel.name).font(.headline)
                    Text("ID: \(tunnel.id)").font(.caption).foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "lock.fill")
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}

struct PasswordPromptView: View {
    let tunnel: Tunnel
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
