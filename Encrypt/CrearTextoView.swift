import SwiftUI

struct TextoSimple: Identifiable, Equatable {
    let id = UUID()
    let nombre: String
    let url: URL
    let fecha: Date
}

struct CrearTextoView: View {
    @State private var textos: [TextoSimple] = []
    @State private var mostrarFormulario = false
    @State private var mostrarLector = false
    @State private var notaEditando: TextoSimple? = nil
    @State private var contenidoEditando: String = ""
    @State private var notaLeyendo: TextoSimple? = nil
    @State private var contenidoLeyendo: String = ""
    @State private var notaSeleccionadaParaCifrar: TextoSimple? = nil
    @State private var mostrarSheetCifrado = false
    
    let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

    var body: some View {
        VStack {
            // TÍTULO Y BOTÓN +
            HStack {
                Text("Notas de texto")
                    .font(.title2).bold()
                Spacer()
                Button(action: {
                    notaEditando = nil
                    contenidoEditando = ""
                    mostrarFormulario = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)

            // LISTA DE NOTAS
            List {
                ForEach(textos) { nota in
                    Button {
                        leerNota(nota)
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.indigo)
                            VStack(alignment: .leading) {
                                Text(nota.nombre)
                                    .bold()
                                Text("Modificada el \(formatDate(nota.fecha))")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            editarNota(nota)
                        } label: {
                            Label("Editar", systemImage: "pencil")
                        }.tint(.orange)
                        Button(role: .destructive) {
                            eliminarNota(nota)
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                        Button {
                            notaSeleccionadaParaCifrar = nota
                            mostrarSheetCifrado = true
                        } label: {
                            Label("Cifrar", systemImage: "lock")
                        }.tint(.blue)
                    }
                }
            }
        }
        .onAppear(perform: cargarNotas)

        // Editor
        .sheet(isPresented: $mostrarFormulario) {
            EditorTextoView(
                nombreInicial: notaEditando?.nombre ?? "",
                contenidoInicial: contenidoEditando,
                onGuardar: { nombre, contenido in
                    let url = folder.appendingPathComponent("\(nombre).txt")
                    do {
                        try contenido.write(to: url, atomically: true, encoding: .utf8)
                        cargarNotas()
                        mostrarFormulario = false
                    } catch {
                        print("❌ Error al guardar nota: \(error)")
                    }
                }
            )
        }

        // Lector
        .sheet(isPresented: $mostrarLector) {
            NavigationView {
                ScrollView {
                    Text(contenidoLeyendo)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .navigationTitle(notaLeyendo?.nombre ?? "Nota")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") {
                            mostrarLector = false
                        }
                    }
                }
            }
        }

        // Sheet para cifrado con interfaz avanzada
        .sheet(isPresented: $mostrarSheetCifrado) {
            if let nota = notaSeleccionadaParaCifrar {
                SheetFormularioCifrado(
                    archivoURL: nota.url,
                    onFinish: { _ in
                        mostrarSheetCifrado = false
                    },
                    isPresented: $mostrarSheetCifrado
                )
            }
        }
    }

    // CARGA INICIAL
    func cargarNotas() {
        do {
            let archivos = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])
            textos = archivos.filter { $0.pathExtension == "txt" }.compactMap {
                let fecha = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
                return TextoSimple(nombre: $0.lastPathComponent, url: $0, fecha: fecha)
            }.sorted { $0.fecha > $1.fecha }
        } catch {
            print("❌ Error cargando notas: \(error)")
        }
    }

    func editarNota(_ nota: TextoSimple) {
        do {
            let contenido = try String(contentsOf: nota.url, encoding: .utf8)
            notaEditando = nota
            contenidoEditando = contenido
            mostrarFormulario = true
        } catch {
            print("❌ Error leyendo nota: \(error)")
        }
    }

    func leerNota(_ nota: TextoSimple) {
        do {
            contenidoLeyendo = try String(contentsOf: nota.url, encoding: .utf8)
            notaLeyendo = nota
            mostrarLector = true
        } catch {
            print("❌ Error leyendo nota: \(error)")
        }
    }

    func eliminarNota(_ nota: TextoSimple) {
        do {
            try FileManager.default.removeItem(at: nota.url)
            cargarNotas()
        } catch {
            print("❌ Error al eliminar nota: \(error)")
        }
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
