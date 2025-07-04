import SwiftUI

struct EditorTextoView: View {
    @Environment(\.dismiss) var dismiss

    @State var nombreInicial: String
    @State var contenidoInicial: String
    @State private var alias: String = ""
    @State private var contenido: String = ""

    var onGuardar: (String, String) -> Void
    var body: some View {
        NavigationView {
            VStack {
                TextField("Nombre del archivo", text: $alias)
                    .textFieldStyle(.roundedBorder)
                    .padding()

                TextEditor(text: $contenido)
                    .padding()
                    .border(Color.gray.opacity(0.3))

                Spacer()
            }
            .navigationTitle("Editar nota")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        onGuardar(alias, contenido)
                        dismiss()
                    }
                    .disabled(alias.isEmpty || contenido.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            alias = nombreInicial.replacingOccurrences(of: ".txt", with: "")
            contenido = contenidoInicial
        }
    }
}
