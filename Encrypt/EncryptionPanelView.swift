import SwiftUI

struct EncryptionPanelView: View {
    enum Opcion: String, CaseIterable, Identifiable {
        case crearLlaves = "Crear llaves"
        case crearTexto = "Crear archivo"
        case cifrarArchivo = "Cifrar archivo"
        case descifrarArchivo = "Descifrar archivo"

        var id: String { self.rawValue }

        var icono: String {
            switch self {
            case .crearLlaves: return "key.fill"
            case .crearTexto: return "square.and.pencil"
            case .cifrarArchivo: return "lock.doc.fill"
            case .descifrarArchivo: return "lock.open.fill"
            }
        }
    }

    @State private var seleccion: Opcion = .crearLlaves

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                VStack {
                    Spacer()
                    VStack(spacing: 20) {
                        ForEach(Opcion.allCases) { opcion in
                            Button(action: {
                                seleccion = opcion
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: opcion.icono)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 36, height: 36)
                                        .foregroundColor(seleccion == opcion ? Color(hex: "#00BCD4") : .gray)
                                    Text(opcion.rawValue)
                                        .font(.caption2)
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(seleccion == opcion ? Color(hex: "#00BCD4") : .gray)
                                        .frame(width: 60)
                                    
                                }
                            }
                            .padding(.vertical, 10)
                        }
                    }
                    Spacer()
                }
                .frame(width: geo.size.width * 0.2)
                .background(Color(.systemGray6))

                Divider()

                ZStack {
                    switch seleccion {
                    case .crearLlaves:
                        CrearLlavesView()
                    case .crearTexto:
                        CrearTextoView()
                    case .cifrarArchivo:
                        CifrarArchivoView()
                    case .descifrarArchivo:
                        DescifrarArchivoView()
                    }
                }
                .frame(width: geo.size.width * 0.8)
            }
            .navigationBarHidden(true)
        }
    }
}
