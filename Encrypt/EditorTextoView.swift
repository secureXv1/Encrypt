import SwiftUI

import SwiftUI

struct EditorTextoView: View {
    let nombreInicial: String
    let contenidoInicial: String
    let onGuardar: (String, String) -> Void
    let onCifrar: (String, String) -> Void

    @State private var nombre: String
    @State private var contenido: String
    @FocusState private var campoActivo: CampoActivo?

    enum CampoActivo: Hashable {
        case nombre, contenido
    }

    init(nombreInicial: String, contenidoInicial: String,
         onGuardar: @escaping (String, String) -> Void,
         onCifrar: @escaping (String, String) -> Void) {
        self.nombreInicial = nombreInicial
        self.contenidoInicial = contenidoInicial
        self.onGuardar = onGuardar
        self.onCifrar = onCifrar
        _nombre = State(initialValue: nombreInicial)
        _contenido = State(initialValue: contenidoInicial)
    }

    var body: some View {
        NavigationView {
            VStack {
                TextField("Título de la nota", text: $nombre)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .focused($campoActivo, equals: .nombre)

                TextEditor(text: $contenido)
                    .padding()
                    .border(Color.gray.opacity(0.4), width: 1)
                    .cornerRadius(8)
                    .focused($campoActivo, equals: .contenido)

                Spacer()

                HStack {
                    Button("Guardar") {
                        let nombreFinal = nombre.hasSuffix(".txt") ? nombre : "\(nombre).txt"
                        onGuardar(nombreFinal, contenido)
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.green)
                    .cornerRadius(10)

                    Button("Cifrar") {
                        let nombreFinal = nombre.hasSuffix(".txt") ? nombre : "\(nombre).txt"
                        onCifrar(nombreFinal, contenido)
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("Editar nota")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    campoActivo = .contenido
                }
            }
        }
    }
}

