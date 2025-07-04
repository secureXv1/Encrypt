import SwiftUI

struct HomeView: View {
    let columnas = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Encabezado
                    //VStack(alignment: .leading, spacing: 6) {
                        //Text("Encrypt")
                            //.font(.largeTitle).bold()
                            //.foregroundColor(.cyan)

                        //Text("Todo en uno: comunicación y cifrado seguro.")
                            //.foregroundColor(.gray)
                            //.font(.subheadline)
                    //}
                    //.padding(.horizontal)
                    
                    Image("BluePost")
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .padding(.horizontal)

                    // Grid de secciones
                    LazyVGrid(columns: columnas, spacing: 12) {
                        ForEach(secciones, id: \.titulo) { seccion in
                            VStack(spacing: 8) {
                                Image(systemName: seccion.icono)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.cyan)

                                Text(seccion.titulo)
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.white)

                                Text(seccion.descripcion)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, minHeight: 140)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(14)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top)
            }
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .navigationBarHidden(true)
            .onAppear {
                ClientService.shared.registrarCliente { success in
                    print(success ? "✅ Cliente registrado desde HomeView" : "❌ Falló el registro")
                }
            }
        }
    }

    let secciones: [Seccion] = [
        //.init(icono: "checkmark.shield.fill", titulo: "Seguridad", descripcion: "Tu información siempre protegida."),
        .init(icono: "lock.shield.fill", titulo: "Cifrado avanzado", descripcion: "Blindaje total para tus archivos."),
        .init(icono: "antenna.radiowaves.left.and.right", titulo: "Túneles privados", descripcion: "Solo quienes deben ver, verán."),
        .init(icono: "eye.slash.fill", titulo: "Control total", descripcion: "Sin rastreo. Sin sorpresas."),
        .init(icono: "wifi.slash", titulo: "Sin internet", descripcion: "Funciona incluso sin conexión."),
        .init(icono: "exclamationmark.triangle.fill", titulo: "Crítico", descripcion: "Ideal para seguridad institucional."),
        .init(icono: "eye.fill", titulo: "Archivos ocultos", descripcion: "Invisibles para ojos no autorizados."),
        .init(icono: "rectangle.inset.filled.and.person.filled", titulo: "Modo discreto", descripcion: "Sin marcas ni huellas."),
        .init(icono: "person.crop.circle.badge.questionmark", titulo: "Identidad flexible", descripcion: "Distintos alias según el contexto.")
    ]
}

struct Seccion {
    let icono: String
    let titulo: String
    let descripcion: String
}
